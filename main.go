package main

import (
	"encoding/base64"
	"fmt"
)

func main() {
	out := base64.StdEncoding.EncodeToString([]byte("managedcloud-dev-df-platform-storage-bucket"))
	fmt.Println("OUT:", out)
}
