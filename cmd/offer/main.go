package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"math/rand"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	jsoniter "github.com/json-iterator/go"
	"github.com/pion/randutil"
	"github.com/pion/webrtc/v3"
)

type message struct {
	MsgString string `json:"msg_string"`
	TimeStamp int    `json:"time_stamp"`
}

func main() { //nolint:gocognit
	offerAddr := flag.String("offer-address", "0.0.0.0:50000", "Address that the Offer HTTP server is hosted on.")
	answerAddrs := flag.String("answer-address", "http://localhost:60000", "Address that the Answer HTTP server is hosted on.")
	// answerAddr := flag.String("answer-address", "http://a984b37a679304ab38db225bbd07cd7f-1634274632.ap-southeast-1.elb.amazonaws.com", "Address that the Answer HTTP server is hosted on.")
	bucketName := flag.String("bucket-name", "", "S3 bucket name to upload files to.")
	turns := flag.String("turns", "", "TURN server addresses.")
	numMsg := flag.Int("num_msg", 1000000, "Number of messages that are going to be sent.")
	// turnAddr := flag.String("turn-addr", "127.0.0.1:3478", "TURN address.")

	flag.Parse()

	fmt.Println("answer: ", *answerAddrs)

	if bucketName == nil {
		fmt.Println(errors.New("missing bucket name"))
		return
	}

	var candidatesMux sync.Mutex
	pendingCandidates := make([]*webrtc.ICECandidate, 0)

	turnServers := strings.Split(*turns, ",")
	for i, t := range turnServers {
		turnServers[i] = fmt.Sprintf("turn:%s", t)
	}
	answerers := strings.Split(*answerAddrs, ",")

	// Prepare the configuration
	// Prepare the configuration
	config := webrtc.Configuration{
		ICEServers: []webrtc.ICEServer{
			{
				URLs: []string{"stun:stun.l.google.com:19302"},
			},
		},
	}

	if len(turnServers) >= 1 {
		if turnServers[0] != "turn:" {
			config.ICEServers = append(config.ICEServers, webrtc.ICEServer{
				URLs:       turnServers,
				Username:   "username1",
				Credential: "key1",
			})
		}
	}

	// Create a new RTCPeerConnection
	peerConnection, err := webrtc.NewPeerConnection(config)
	if err != nil {
		fmt.Printf("error 1: %v", err.Error())
		return
	}
	defer func() {
		if cErr := peerConnection.Close(); cErr != nil {
			fmt.Printf("cannot close peerConnection: %v\n", cErr)
		}
	}()

	// When an ICE candidate is available send to the other Pion instance
	// the other Pion instance will add this candidate by calling AddICECandidate
	peerConnection.OnICECandidate(func(c *webrtc.ICECandidate) {
		if c == nil {
			return
		}

		candidatesMux.Lock()
		defer candidatesMux.Unlock()
		fmt.Println("CANDIDATE:", *c)
		desc := peerConnection.RemoteDescription()
		if desc == nil {
			pendingCandidates = append(pendingCandidates, c)
		} else if onICECandidateErr := signalCandidate(answerers, c); onICECandidateErr != nil {
			fmt.Println("error 2:", onICECandidateErr.Error())
		}
	})

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// A HTTP handler that allows the other Pion instance to send us ICE candidates
	// This allows us to add ICE candidates faster, we don't have to wait for STUN or TURN
	// candidates which may be slower
	http.HandleFunc("/candidate", func(_ http.ResponseWriter, r *http.Request) {
		candidate, candidateErr := ioutil.ReadAll(r.Body)
		if candidateErr != nil {
			fmt.Println("error 3:", candidateErr.Error())
			return
		}
		if candidateErr := peerConnection.AddICECandidate(webrtc.ICECandidateInit{Candidate: string(candidate)}); candidateErr != nil {
			fmt.Println("error 4:", candidateErr.Error())
			return
		}
	})

	// A HTTP handler that processes a SessionDescription given to us from the other Pion process
	http.HandleFunc("/sdp", func(_ http.ResponseWriter, r *http.Request) {
		sdp := webrtc.SessionDescription{}
		if sdpErr := json.NewDecoder(r.Body).Decode(&sdp); sdpErr != nil {
			fmt.Println("error 5:", sdpErr.Error())
			return
		}

		if sdpErr := peerConnection.SetRemoteDescription(sdp); sdpErr != nil {
			fmt.Println("error 6:", sdpErr.Error())
			return
		}

		candidatesMux.Lock()
		defer candidatesMux.Unlock()

		for _, c := range pendingCandidates {
			if onICECandidateErr := signalCandidate(answerers, c); onICECandidateErr != nil {
				fmt.Println("error 7:", onICECandidateErr.Error())
			}
		}
	})
	// Start HTTP server that accepts requests from the answer process
	go func() { panic(http.ListenAndServe(*offerAddr, nil)) }()

	tcp := "tcp"
	ordered := true
	var maxPacketLifeTime uint16 = 100
	dataChannel, err := peerConnection.CreateDataChannel(fmt.Sprintf("data-%d", 1), &webrtc.DataChannelInit{
		Protocol:          &tcp,
		Ordered:           &ordered,
		MaxPacketLifeTime: &maxPacketLifeTime,
	})
	if err != nil {
		fmt.Printf("error 8: %v", err.Error())
		return
	}

	dataChannel.SetBufferedAmountLowThreshold(100000)
	// Register channel opening handling
	dataChannel.OnOpen(func() {
		var start = time.Now()
		fileName := fmt.Sprint("offerer_", time.Now().Format(time.RFC3339), ".txt")
		file, err := os.Create(fileName)
		if err != nil {
			fmt.Println(("error creating log file"))
			return
		}
		defer file.Close()

		writer := bufio.NewWriterSize(file, 4096)
		// TODO: refactor the message struct to include the initial sending time for the answerer to calculate the latency
		msg, err := RandSeq(242)
		if err != nil {
			fmt.Println("err generating msg:", err.Error())
			return
		}
		json := jsoniter.ConfigFastest // Use the fastest encoding mode
		var msgs []message

		fmt.Println("PROTOCOL:", dataChannel.Protocol())
		for i := 1; i <= *numMsg; i++ {
			// Send the message as text
			msgs = append(msgs, message{
				MsgString: msg,
			})

			// can only send batch data less than 65535 bytes, here we send 200 messages (250 bytes each) which are 50000 bytes
			if i%200 == 0 {
				now := time.Now().UTC().UnixNano()
				for i := range msgs {
					msgs[i].TimeStamp = int(now)
				}
				data, err := json.Marshal(msgs)
				if err != nil {
					fmt.Println("ERROR 9:", err.Error())
					return
				}
				msgs = []message{} // empty the batch for later uses
				sendTextErr := dataChannel.Send(data)
				if sendTextErr != nil {
					fmt.Println("error sending data:", sendTextErr.Error())
					return
				}
				time.Sleep(700000 * time.Nanosecond) // sleep 0.7 ms
			}

			if i%(*numMsg/10) == 0 {
				_, err := fmt.Fprintf(writer, "produce %d messages at speed %.2f/ms\n", i, float64(i)/float64(time.Since(start).Milliseconds()))
				if err != nil {
					fmt.Println("error write to file", err.Error())
					return
				}
			}
		}

		time.Sleep(20 * time.Second)
		if err := dataChannel.Close(); err != nil {
			fmt.Printf("error closing data channels %d: %s\n", *dataChannel.ID(), err.Error())
			return
		}

		upload(writer, file, *bucketName, fileName)
		fmt.Println("DONE!")
	})

	// Register text message handling
	dataChannel.OnMessage(func(msg webrtc.DataChannelMessage) {
	})

	// Set the handler for Peer connection state
	// This will notify you when the peer has connected/disconnected
	peerConnection.OnConnectionStateChange(func(s webrtc.PeerConnectionState) {
		fmt.Printf("Peer Connection State has changed: %s\n", s.String())

		if s == webrtc.PeerConnectionStateFailed {
			// Wait until PeerConnection has had no network activity for 30 seconds or another failure. It may be reconnected using an ICE Restart.
			// Use webrtc.PeerConnectionStateDisconnected if you are interested in detecting faster timeout.
			// Note that the PeerConnection may come back from PeerConnectionStateDisconnected.
			fmt.Println("Peer Connection has gone to failed exiting")
			fmt.Println("About to retry...")
			time.Sleep(5 * time.Second)
			// sendOffer(peerConnection, answerers)
			// os.Exit(0)
		}
	})

	sendOffer(peerConnection, answerers)

	// Block forever
	select {}
}

func signalCandidate(answerers []string, c *webrtc.ICECandidate) error {
	payload := []byte(c.ToJSON().Candidate)
	for _, a := range answerers {
		resp, err := http.Post(fmt.Sprintf("%s/candidate", a), "application/json; charset=utf-8", bytes.NewReader(payload)) //nolint:noctx
		if err != nil {
			return err
		}
		resp.Body.Close()
	}

	return nil
}

func exchangeSDPtWithRetry(payload []byte, answerAddr string) (*http.Response, error) {
	var resp *http.Response
	var err error
	startTime := time.Now()

	for time.Since(startTime) < 3*time.Minute {
		resp, err = http.Post(fmt.Sprintf("%s/sdp", answerAddr), "application/json; charset=utf-8", bytes.NewReader(payload)) // nolint:noctx
		if err == nil {
			return resp, nil
		}
		fmt.Printf("ERROR 10: %v\n", err.Error())
		time.Sleep(5 * time.Second)
	}

	return nil, fmt.Errorf("timeout reached")
}

func sendOffer(peerConnection *webrtc.PeerConnection, answerers []string) {
	wg := new(sync.WaitGroup)
	// Create an offer to send to the other process
	offer, err := peerConnection.CreateOffer(nil)
	if err != nil {
		fmt.Printf("ERROR 11: %v", err.Error())
		return
	}

	// Sets the LocalDescription, and starts our UDP listeners
	// Note: this will start the gathering of ICExx candidates
	if err = peerConnection.SetLocalDescription(offer); err != nil {
		fmt.Printf("ERROR 12: %v\n", err.Error())
		return
	}

	// Send our offer to the HTTP server listening in the other process
	payload, err := json.Marshal(offer)
	if err != nil {
		fmt.Printf("ERROR 13: %v", err.Error())
		return
	}
	for _, a := range answerers {
		wg.Add(1)
		go func(answer string) {
			resp, err := exchangeSDPtWithRetry(payload, answer)
			if err != nil {
				fmt.Printf("ERROR 14: %v\n", err.Error())
				return
			} else if err := resp.Body.Close(); err != nil {
				fmt.Printf("ERROR 7: %v\n", err.Error())
				return
			}
		}(a)
	}
	wg.Wait()
	fmt.Println("HERE")
}

func RandSeq(n int) (string, error) {
	val, err := randutil.GenerateCryptoRandomString(n, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
	if err != nil {
		return "", err
	}

	return val, nil
}

func RanNum() int {
	rand.Seed(time.Now().UnixNano())
	return rand.Intn(101)
}

func upload(writer *bufio.Writer, file *os.File, bucketName, fileName string) error {
	fmt.Println("got upload()")
	err := writer.Flush()
	if err != nil {
		fmt.Println("error flushing data into file:", err.Error())
		return err
	}

	_, err = file.Seek(0, 0)
	if err != nil {
		fmt.Println("Failed to seek file to beginning:", err)
		return err
	}

	session := session.Must(session.NewSession(&aws.Config{
		Credentials: credentials.NewStaticCredentialsFromCreds(credentials.Value{ // sets the credentials for the session. The "credentials" package is used to create a static set of credentials from the "AccessKeyID" and "SecretAccessKey" values stored in the "AWS" struct.
			AccessKeyID:     os.Getenv("AWS_KEY_ID"),
			SecretAccessKey: os.Getenv("AWS_SECRET_KEY"),
		}),
		Region:     aws.String(os.Getenv("AWS_REGION")), // sets the region for the session. The "awslib" package is used to create a string value for the region based on the "Region" value stored in the "AWS" struct.
		MaxRetries: aws.Int(3),                          // sets the maximum number of retries for AWS requests. The "awslib" package is used to create an integer value of 3.
	}))
	s3Service := s3.New(session)
	_, err = s3Service.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String(fileName),
		Body:   file,
	})
	if err != nil {
		fmt.Println(("error uploading"), err)
		return err
	}
	return nil
}
