package pocketbase

import (
	"testing"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
)

func MigrationCount(t *testing.T, app core.App) int {
	t.Helper()
	count := 0
	if err := app.DB().NewQuery("SELECT COUNT(*) FROM _migrations WHERE file = '1793491200_initial.js'").Row(&count); err != nil {
		t.Fatal(err)
	}
	return count
}
