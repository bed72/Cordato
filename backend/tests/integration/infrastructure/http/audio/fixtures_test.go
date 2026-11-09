package audio_test

import (
	"net/http"
	"testing"

	audiohttp "cordato/backend/internal/infrastructure/http/audio"

	"ganigeorgiev.com/pocketbase/pocketbase/apis"
	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"ganigeorgiev.com/pocketbase/pocketbase/tests"
)

func audioHandler(t *testing.T, accept audiohttp.Acceptor) (http.Handler, string, string, string) {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	app.Settings().Logs.MaxDays = 0
	app.Settings().RateLimits.Enabled = false
	verified := authToken(t, app, "users", "audio-verified@example.test", true)
	unverified := authToken(t, app, "users", "audio-unverified@example.test", false)
	admin := authToken(t, app, "_superusers", "audio-admin@example.test", true)
	routes, err := apis.NewRouter(app)
	if err != nil {
		t.Fatal(err)
	}
	audiohttp.Register(routes, accept)
	handler, err := routes.BuildMux()
	if err != nil {
		t.Fatal(err)
	}
	return handler, verified, unverified, admin
}

func authToken(t *testing.T, app core.App, collectionName, email string, verified bool) string {
	t.Helper()
	collection, err := app.FindCollectionByNameOrId(collectionName)
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(collection)
	user.SetEmail(email)
	user.SetPassword("Cordato123456")
	user.SetVerified(verified)
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}
	token, err := user.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}
	return token
}
