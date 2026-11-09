package pocketbase_test

import (
	"os"
	"path/filepath"
	"testing"

	pbtest "cordato/backend/tests/support/pocketbase"
)

func TestJavaScriptMigrationAndRestart(t *testing.T) {
	app := pbtest.NewApplication(t)
	for _, name := range []string{"users", "expenses", "metrics"} {
		if _, err := app.FindCollectionByNameOrId(name); err != nil {
			t.Fatalf("collection %s: %v", name, err)
		}
	}
	if app.Settings().Meta.AppName != "Cordato" || !app.Settings().SMTP.Enabled {
		t.Fatal("settings da migration não foram carregados")
	}
	admin, err := app.FindAuthRecordByEmail("_superusers", "admin@example.test")
	if err != nil {
		t.Fatal(err)
	}
	user := pbtest.CreateUser(t, app, "persisted@example.test", true)
	if pbtest.MigrationCount(t, app) != 1 {
		t.Fatal("histórico deve conter exatamente uma aplicação da migration inicial")
	}
	if err := app.ClearBootstrap(); err != nil {
		t.Fatal(err)
	}
	t.Setenv("POCKETBASE_ADMIN_EMAIL", "")
	t.Setenv("POCKETBASE_ADMIN_PASSWORD", "")
	t.Setenv("SMTP_PASSWORD", "")
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	if err := app.RunAllMigrations(); err != nil {
		t.Fatalf("reinício não deve reaplicar o bootstrap inicial: %v", err)
	}
	if pbtest.MigrationCount(t, app) != 1 {
		t.Fatal("reinício alterou o histórico da migration inicial")
	}
	for _, identity := range []struct{ collection, id string }{{"users", user.Id}, {"_superusers", admin.Id}} {
		if _, err := app.FindRecordById(identity.collection, identity.id); err != nil {
			t.Fatal("registro não foi preservado no reinício")
		}
	}
	if _, err := os.Stat(filepath.Join(app.DataDir(), "types.d.ts")); err != nil {
		t.Fatal(err)
	}
}
