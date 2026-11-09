package pocketbase

import (
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
)

func CreateUser(t *testing.T, app core.App, email string, verified bool) *core.Record {
	t.Helper()
	collection, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(collection)
	user.SetEmail(email)
	user.SetPassword("Cordato123")
	user.SetVerified(verified)
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	return user
}
