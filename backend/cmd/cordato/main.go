package main

import (
	"log"

	"cordato/backend/internal/bootstrap"

	pb "ganigeorgiev.com/pocketbase/pocketbase"
)

func main() {
	app, err := bootstrap.New(pb.Config{})
	if err != nil {
		log.Fatal(err)
	}

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
