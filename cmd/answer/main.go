package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/pion/webrtc/v3"
	"gonum.org/v1/plot"
	"gonum.org/v1/plot/plotter"
	"gonum.org/v1/plot/vg"
)

type message struct {
	MsgString string `json:"msg_string"`
	TimeStamp int    `json:"time_stamp"`
}

type latency struct {
	deliver int
	arrive  int
	dif     int
}

type receivePacket struct {
	Data       []byte
	ArriveTime int
}

func main() { // nolint:gocognit
	offerAddr := flag.String("offer-address", "http://0.0.0.0:50000", "Address that the Offer HTTP server is hosted on.")
	answerAddr := flag.String("answer-address", "0.0.0.0:60000", "Address that the Answer HTTP server is hosted on.")
	bucketName := flag.String("bucket-name", "", "S3 bucket name to upload files to.")
	turns := flag.String("turns", "", "TURN address.")
	numMsg := flag.Int("num_msg", 1000000, "Number of messages that are going to be sent.")
	// maxNumMsgReceived := flag.Int("max_num_msg_received", 100000, "Number of maximum messages to be received before breaking out for analyticals")
	// turnAddr := flag.String("turn-addr", "127.0.0.1:3478", "TURN address.")

	flag.Parse()

	if bucketName == nil {
		fmt.Println(errors.New("missing bucket name"))
		return
	}

	var candidatesMux sync.Mutex
	pendingCandidates := make([]*webrtc.ICECandidate, 0)
	// Everything below is the Pion WebRTC API! Thanks for using it ❤️.
	turnServers := strings.Split(*turns, ",")
	for i, t := range turnServers {
		turnServers[i] = fmt.Sprintf("turn:%s", t)
	}

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
		fmt.Printf("error 1: %v\n", err.Error())
		return
	}
	defer func() {
		if err := peerConnection.Close(); err != nil {
			fmt.Printf("cannot close peerConnection: %v\n", err)
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
		} else if onICECandidateErr := signalCandidate(*offerAddr, c); onICECandidateErr != nil {
			fmt.Printf("error 2: %v\n", onICECandidateErr.Error())
			return
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
			fmt.Printf("error 3: %v\n", candidateErr.Error())
			return
		}
		if candidateErr := peerConnection.AddICECandidate(webrtc.ICECandidateInit{Candidate: string(candidate)}); candidateErr != nil {
			fmt.Printf("error 4: %v\n", candidateErr.Error())
			return
		}
	})

	// A HTTP handler that processes a SessionDescription given to us from the other Pion process
	http.HandleFunc("/sdp", func(_ http.ResponseWriter, r *http.Request) {
		sdp := webrtc.SessionDescription{}
		if err := json.NewDecoder(r.Body).Decode(&sdp); err != nil {
			fmt.Printf("error 5: %v\n", err.Error())
			return
		}

		if err := peerConnection.SetRemoteDescription(sdp); err != nil {
			fmt.Printf("error 6: %v\n", err.Error())
			return
		}

		// Create an answer to send to the other process
		answer, err := peerConnection.CreateAnswer(nil)
		if err != nil {
			fmt.Printf("error 7: %v\n", err.Error())
			return
		}

		// Sets the LocalDescription, and starts our UDP listeners
		err = peerConnection.SetLocalDescription(answer)
		if err != nil {
			fmt.Printf("error 11: %v\n", err.Error())
			return
		}

		// Send our answer to the HTTP server listening in the other process
		payload, err := json.Marshal(answer)
		if err != nil {
			fmt.Printf("error 8: %v\n", err.Error())
			return
		}
		resp, err := exchangeSDPtWithRetry(payload, *offerAddr)
		if err != nil {
			fmt.Printf("error 9: %v\n", err.Error())
			return
		} else if closeErr := resp.Body.Close(); closeErr != nil {
			fmt.Printf("error 10: %v\n", err.Error())
			return
		}

		candidatesMux.Lock()
		for _, c := range pendingCandidates {
			onICECandidateErr := signalCandidate(*offerAddr, c)
			if onICECandidateErr != nil {
				fmt.Printf("error 12: %v\n", onICECandidateErr.Error())
				return
			}
		}
		candidatesMux.Unlock()
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
			//os.Exit(0)
		}
	})

	// json := jsoniter.ConfigFastest // Use the fastest encoding mode
	ls := []latency{}
	var count int64
	fileName := fmt.Sprint("answerer_", time.Now().Format(time.RFC3339), ".txt")
	file, err := os.Create(fileName)
	if err != nil {
		fmt.Println(("error creating log file"))
		return
	}
	defer file.Close()

	writer := bufio.NewWriterSize(file, 4096)
	var mu sync.Mutex
	goDataChannel := make(map[uint16]chan receivePacket)
	// Register data channel creation handling
	peerConnection.OnDataChannel(func(d *webrtc.DataChannel) {
		webRTCDataChannelID := *d.ID()
		fmt.Printf("New DataChannel %s (name) - %d (id)\n", d.Label(), webRTCDataChannelID)

		var start = time.Now()
		numWorkers := 10
		goDataChannel[webRTCDataChannelID] = make(chan receivePacket) // un-buffered channel to maintain the order of receiving messages with respect to their arrival
		for i := 0; i < numWorkers; i++ {
			go func() {
				for rp := range goDataChannel[webRTCDataChannelID] {
					var messagesFromOfferer []message
					if err := json.Unmarshal(rp.Data, &messagesFromOfferer); err != nil {
						fmt.Println("error 17:", err.Error())
						return
					}

					atomic.AddInt64(&count, int64(len(messagesFromOfferer)))
					if int(atomic.LoadInt64(&count))%(*numMsg/10) == 0 {
						_, err := fmt.Fprintf(writer, "receive %d messages at speed %.2f/ms\n", count, float64(count)/float64(time.Since(start).Milliseconds()))
						if err != nil {
							fmt.Println("error 18:", err.Error())
							return
						}
					}

					for _, m := range messagesFromOfferer {
						mu.Lock()
						ls = append(ls, latency{
							deliver: m.TimeStamp,
							arrive:  rp.ArriveTime,
							dif:     rp.ArriveTime - m.TimeStamp,
						})
						mu.Unlock()
					}
				}
			}()
		}

		go func() {
			// Close the worker channel when all packets have been processed
			for rp := range goDataChannel[webRTCDataChannelID] {
				goDataChannel[webRTCDataChannelID] <- rp
			}
		}()

		d.OnMessage(func(msg webrtc.DataChannelMessage) {
			goDataChannel[webRTCDataChannelID] <- receivePacket{Data: msg.Data, ArriveTime: int(time.Now().UTC().UnixNano())}
		})

		d.OnClose(func() {
			close(goDataChannel[webRTCDataChannelID])
			fmt.Println("DATA CHANNEL IS CLOSED, ABOUT TO AGGREGATE MESSAGES AND CALCULATE STATISTICS ...")

			// calculate metrics
			if len(ls) != 0 {
				var min, max latency
				var sum, avg int
				ls[0].dif = ls[0].arrive - ls[0].deliver
				min, max = ls[0], ls[0]
				for _, l := range ls {
					if l.dif < min.dif {
						min = l
					} else if l.dif > max.dif {
						max = l
					}
					sum += int(l.dif)
				}
				avg = sum / len(ls)
				// got all pre metrics
				nextMax := nextDivisibleByTen(int(max.dif))
				spectrums := map[float64]int{}
				for idx, l := range ls {
					_ = idx
					switch {
					case int(l.dif) < nextMax-9*(nextMax/10):
						spectrums[float64(nextMax-9*(nextMax/10))/1e6]++
					case int(l.dif) < nextMax-8*(nextMax/10):
						spectrums[float64(nextMax-8*(nextMax/10))/1e6]++
					case int(l.dif) < nextMax-7*(nextMax/10):
						spectrums[float64(nextMax-7*(nextMax/10))/1e6]++
					case int(l.dif) < nextMax-6*(nextMax/10):
						spectrums[float64(nextMax-6*(nextMax/10))/1e6]++
					case int(l.dif) < nextMax-5*(nextMax/10):
						spectrums[float64(nextMax-5*(nextMax/10))/1e6]++
					case int(l.dif) < nextMax-4*(nextMax/10):
						spectrums[float64(nextMax-4*(nextMax/10))/1e6]++
					case int(l.dif) < nextMax-3*(nextMax/10):
						spectrums[float64(nextMax-3*(nextMax/10))/1e6]++
					case int(l.dif) < nextMax-2*(nextMax/10):
						spectrums[float64(nextMax-2*(nextMax/10))/1e6]++
					case int(l.dif) < nextMax-(nextMax/10):
						spectrums[float64(nextMax-(nextMax/10))/1e6]++
					case int(l.dif) < nextMax:
						spectrums[float64(nextMax)/1e6]++
					}
				}
				fmt.Fprintf(writer, "#### SPECTRUMS ####\n")

				keys := make([]float64, 0)
				for k := range spectrums {
					keys = append(keys, k)
				}
				sort.Float64s(keys)
				for _, k := range keys {
					fmt.Fprintf(writer, "%d messages have latencies less than %.2f ms\n", spectrums[k], k)
				}
				fmt.Fprintf(writer, "MIN LATENCY %.2f ms, MAX LATENCY %.2f ms, AVG LATENCY %.2f ms\n", float64(min.dif)/1e6, float64(max.dif)/1e6, float64(avg)/1e6)

				barChartFile, barChartFileName, err := genBarChart(ls)
				if err != nil {
					fmt.Println("error while genarating bar chart", err.Error())
					return
				}
				defer barChartFile.Close()
				fmt.Println("Generated bar chart")

				upload(writer, file, barChartFile, *bucketName, fileName, barChartFileName)
				fmt.Println("DONE!")
			}
		})

		// // Register channel opening handling
		// d.OnOpen(func() {})
	})
	// Start HTTP server that accepts requests from the offer process to exchange SDP and Candidates
	panic(http.ListenAndServe(*answerAddr, nil))
}

func signalCandidate(addr string, c *webrtc.ICECandidate) error {
	payload := []byte(c.ToJSON().Candidate)
	resp, err := http.Post(fmt.Sprintf("%s/candidate", addr), // nolint:noctx
		"application/json; charset=utf-8", bytes.NewReader(payload))
	if err != nil {
		return err
	}

	return resp.Body.Close()
}

func exchangeSDPtWithRetry(payload []byte, offerAddr string) (*http.Response, error) {
	var resp *http.Response
	var err error
	startTime := time.Now()

	for time.Since(startTime) < 3*time.Minute {
		resp, err = http.Post(fmt.Sprintf("%s/sdp", offerAddr), "application/json; charset=utf-8", bytes.NewReader(payload))
		if err == nil {
			return resp, nil
		}
		fmt.Printf("error 18: %v\n", err.Error())
		time.Sleep(5 * time.Second)
	}

	return nil, fmt.Errorf("timeout reached")
}

func upload(writer *bufio.Writer, file, barChartFile *os.File, bucketName, fileName, barChartFileName string) {
	fmt.Println("got upload()")
	err := writer.Flush()
	if err != nil {
		fmt.Println(("error flushing data from buffer into file"), err)
		return
	}

	_, err = file.Seek(0, 0)
	if err != nil {
		fmt.Println("failed to seek file to beginning:", err)
		return
	}

	if err := toS3(file, bucketName, fileName); err != nil {
		fmt.Println("failed to upload statistic file to S3", err.Error())
		return
	}
	if err := toS3(barChartFile, bucketName, barChartFileName); err != nil {
		fmt.Println("failed to upload latencies chart file to S3", err.Error())
		return
	}
}

func nextDivisibleByTen(num int) int {
	remainder := num % 10
	if remainder == 0 {
		return num
	}
	return num + (10 - remainder)
}

func genBarChart(ls []latency) (*os.File, string, error) {
	// Create a new plot
	p := plot.New()
	// Set the title and labels for the axes
	p.Title.Text = "graph of messages in terms of latencies and its index"
	p.X.Label.Text = fmt.Sprintf("Indexes (0-%d)", len(ls)-1)
	p.Y.Label.Text = "Latencies (ms)"

	// Create a bar chart
	bars := make(plotter.Values, len(ls))
	for i, v := range ls {
		bars[i] = float64(v.dif) / 1e6
	}

	barchart, err := plotter.NewBarChart(bars, vg.Points(50))
	if err != nil {
		fmt.Println("error create new bar chart:", err)
		return nil, "", err
	}

	// Add the bar chart to the plot
	p.Add(barchart)

	// Save the plot to a PNG file
	barChartFileName := "barchart.png"
	if err := p.Save(4*vg.Inch, 4*vg.Inch, barChartFileName); err != nil {
		fmt.Println("error save bar chart:", err)
		return nil, "", err
	}

	file, err := os.Open(barChartFileName)
	if err != nil {
		fmt.Println("error open bar chart file")
		return nil, "", err
	}
	return file, barChartFileName, nil
}

func toS3(file *os.File, bucketName, fileName string) error {
	session := session.Must(session.NewSession(&aws.Config{
		Credentials: credentials.NewStaticCredentialsFromCreds(credentials.Value{ // sets the credentials for the session. The "credentials" package is used to create a static set of credentials from the "AccessKeyID" and "SecretAccessKey" values stored in the "AWS" struct.
			AccessKeyID:     os.Getenv("AWS_KEY_ID"),
			SecretAccessKey: os.Getenv("AWS_SECRET_KEY"),
		}),
		Region:     aws.String(os.Getenv("AWS_REGION")), // sets the region for the session. The "awslib" package is used to create a string value for the region based on the "Region" value stored in the "AWS" struct.
		MaxRetries: aws.Int(3),                          // sets the maximum number of retries for AWS requests. The "awslib" package is used to create an integer value of 3.
	}))
	s3Service := s3.New(session)
	_, err := s3Service.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String(fileName),
		Body:   file,
	})
	if err != nil {
		fmt.Println(("error uploading object to S3"), err)
		return err
	}
	return nil
}
