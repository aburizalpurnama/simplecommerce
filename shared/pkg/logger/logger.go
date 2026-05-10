package logger

import (
	"context"

	"github.com/rs/zerolog"
)

// New membuat zerolog.Logger dengan konfigurasi production-ready.
// JSON format, ISO timestamp, level sesuai environment.
func New(env string) (zerolog.Logger, error) {
	// TODO: implementasi di Sprint 2
	// Contoh default return agar tidak error saat ini:
	return zerolog.Nop(), nil
}

// FromContext mengambil logger dari context.
// Secara native, Zerolog sudah memiliki built-in context integration.
func FromContext(ctx context.Context) *zerolog.Logger {
	// Akan me-return logger bawaan context atau default global logger jika kosong.
	return zerolog.Ctx(ctx)
}
