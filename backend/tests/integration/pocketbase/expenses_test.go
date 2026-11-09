package pocketbase_test

import (
	"fmt"
	"net/http"
	"testing"

	pbtest "cordato/backend/tests/support/pocketbase"
)

func TestExpenseCRUDAndOwnership(t *testing.T) {
	app := pbtest.NewApplication(t)
	owner := pbtest.CreateUser(t, app, "owner@example.test", true)
	other := pbtest.CreateUser(t, app, "other@example.test", true)
	handler := pbtest.NewHandler(t, app)
	ownerToken := pbtest.Login(t, handler, owner.Email())
	otherToken := pbtest.Login(t, handler, other.Email())
	const records = "/api/collections/expenses/records"
	body := fmt.Sprintf(`{"owner":%q,"amount":2590,"description":"Almoço","category":"food","occurred_on":"2026-11-09 00:00:00.000Z"}`, owner.Id)
	pbtest.Request(t, handler, http.MethodPost, records, "", body, http.StatusBadRequest)
	pbtest.Request(t, handler, http.MethodPost, records, otherToken, body, http.StatusBadRequest)
	response := pbtest.Request(t, handler, http.MethodPost, records, ownerToken, body, http.StatusOK)
	created := pbtest.Decode[struct {
		ID     string
		Owner  string
		Amount int64
	}](t, response)
	if created.ID == "" || created.Owner != owner.Id || created.Amount != 2590 {
		t.Fatal("despesa criada com dados incorretos")
	}
	path := records + "/" + created.ID
	pbtest.Request(t, handler, http.MethodGet, path, ownerToken, "", http.StatusOK)
	pbtest.Request(t, handler, http.MethodGet, path, otherToken, "", http.StatusNotFound)
	pbtest.Request(t, handler, http.MethodPatch, path, otherToken, `{"amount":100}`, http.StatusNotFound)
	pbtest.Request(t, handler, http.MethodDelete, path, otherToken, "", http.StatusNotFound)
	pbtest.Request(t, handler, http.MethodPatch, path, ownerToken, fmt.Sprintf(`{"owner":%q}`, other.Id), http.StatusNotFound)
	pbtest.Request(t, handler, http.MethodPatch, path, ownerToken, `{"amount":1.5}`, http.StatusBadRequest)
	pbtest.Request(t, handler, http.MethodPatch, path, ownerToken, `{"amount":3000}`, http.StatusOK)
	response = pbtest.Request(t, handler, http.MethodGet, records, otherToken, "", http.StatusOK)
	if len(pbtest.Decode[struct{ Items []map[string]any }](t, response).Items) != 0 {
		t.Fatal("listagem expôs despesas de outro usuário")
	}
	response = pbtest.Request(t, handler, http.MethodGet, "/api/collections/metrics/records", ownerToken, "", http.StatusOK)
	metrics := pbtest.Decode[struct {
		Items []struct {
			TotalAmount string `json:"total_amount"`
		}
	}](t, response)
	if len(metrics.Items) != 1 || metrics.Items[0].TotalAmount != "3000" {
		t.Fatal("view mensal não refletiu a atualização em centavos")
	}
	response = pbtest.Request(t, handler, http.MethodGet, "/api/collections/metrics/records", otherToken, "", http.StatusOK)
	if len(pbtest.Decode[struct{ Items []map[string]any }](t, response).Items) != 0 {
		t.Fatal("view mensal expôs dados de outro usuário")
	}
	pbtest.Request(t, handler, http.MethodDelete, path, ownerToken, "", http.StatusNoContent)
	pbtest.Request(t, handler, http.MethodGet, path, ownerToken, "", http.StatusNotFound)
}
