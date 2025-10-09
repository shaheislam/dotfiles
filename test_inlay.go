package main

import (
	"fmt"
	"strings"
	"time"
)

func main() {
	// Variable type inference - inlay hints will show types
	name := "John Doe"
	age := 30
	scores := []int{95, 87, 92, 88, 91}
	config := map[string]interface{}{
		"debug":   true,
		"timeout": 30,
		"retries": 3,
	}

	// Function calls with multiple parameters - hints show parameter names
	result := processUser(name, age, true, 2.5, scores)
	fmt.Println(result)

	// Channel operations - hints show channel types
	ch := make(chan string, 10)
	go func() {
		ch <- "Hello from goroutine"
	}()
	msg := <-ch
	fmt.Println(msg)

	// Closures and anonymous functions - hints show captured variables
	multiplier := 5
	calculate := func(x, y int) int {
		return (x + y) * multiplier
	}
	calculation := calculate(10, 20)
	fmt.Println(calculation)

	// Complex type inference with structs
	user := struct {
		Name  string
		Email string
		Admin bool
	}{
		Name:  "Alice",
		Email: "alice@example.com",
		Admin: false,
	}

	// Method chaining - hints show intermediate types
	processed := strings.ToUpper(strings.TrimSpace(strings.Replace(user.Name, " ", "_", -1)))
	fmt.Println(processed)

	// Time operations - hints show duration types
	duration := time.Hour * 2
	deadline := time.Now().Add(duration)
	remaining := time.Until(deadline)
	fmt.Printf("Time remaining: %v\n", remaining)

	// Error handling - hints show error types
	data, err := getData(config)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
	}
	fmt.Println(data)

	// Range operations - hints show iterator variables
	for i, score := range scores {
		fmt.Printf("Score %d: %d\n", i, score)
	}
}

// Complex function with multiple parameters
func processUser(name string, age int, active bool, rating float64, scores []int) string {
	avg := 0.0
	for _, score := range scores {
		avg += float64(score)
	}
	avg /= float64(len(scores))

	return fmt.Sprintf("User: %s, Age: %d, Active: %t, Rating: %.2f, Avg Score: %.2f",
		name, age, active, rating, avg)
}

// Function returning multiple values
func getData(config map[string]interface{}) (string, error) {
	if config["debug"].(bool) {
		return "Debug data", nil
	}
	return "Production data", nil
}

// Generic function (Go 1.18+) - hints show type parameters
func Filter[T any](slice []T, predicate func(T) bool) []T {
	result := make([]T, 0)
	for _, item := range slice {
		if predicate(item) {
			result = append(result, item)
		}
	}
	return result
}

// Interface implementation - hints show interface methods
type Worker interface {
	DoWork() string
}

type Developer struct {
	Language string
}

func (d Developer) DoWork() string {
	return fmt.Sprintf("Writing %s code", d.Language)
}

func executeWorker(w Worker) {
	output := w.DoWork()
	fmt.Println(output)
}
