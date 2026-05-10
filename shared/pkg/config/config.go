package config

import "time"

type Config interface {
	GetString(key string) string
	GetInt(key string) int
	GetBool(key string) bool
	GetDuration(key string) time.Duration
	GetFloat(key string) float64
}

func New() Config {

	// TODO: implement on sprint 2
	return nil
}
