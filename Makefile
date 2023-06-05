.PHONY: offer
offer:
	export GO111MODULE=on
	go run cmd/offer/main.go

.PHONY: answer
answer:
	export GO111MODULE=on
	go run cmd/answer/main.go