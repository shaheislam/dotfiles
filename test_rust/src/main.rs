//! Test file for Rust development setup with rustaceanvim and crates.nvim

use anyhow::Result;
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Test CLI application
#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Optional name to greet
    #[arg(short, long)]
    name: Option<String>,

    /// Number of times to greet
    #[arg(short, long, default_value_t = 1)]
    count: u8,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Process some data
    Process {
        /// Input file path
        #[arg(short, long)]
        input: String,
    },
    /// Analyze something
    Analyze {
        /// Verbose output
        #[arg(short, long)]
        verbose: bool,
    },
}

// Test rustaceanvim's enhanced type inference and inlay hints
#[derive(Debug, Serialize, Deserialize)]
struct Person {
    name: String,
    age: u32,
    email: Option<String>,
}

impl Person {
    fn new(name: impl Into<String>, age: u32) -> Self {
        // Rustaceanvim should show type hints for 'name' parameter
        Self {
            name: name.into(),
            age,
            email: None,
        }
    }

    fn with_email(mut self, email: impl Into<String>) -> Self {
        self.email = Some(email.into());
        self
    }
}

// Test macro expansion (use <leader>re in Neovim)
macro_rules! create_function {
    ($func_name:ident) -> {
        fn $func_name() {
            println!("Function {} was called", stringify!($func_name));
        }
    };
}

create_function!(generated_function);

// Test error handling with Result types
fn process_data(input: &str) -> Result<Vec<String>> {
    // Rustaceanvim should provide good diagnostics here
    let lines: Vec<String> = input
        .lines()
        .map(|line| line.trim().to_string())
        .filter(|line| !line.is_empty())
        .collect();

    if lines.is_empty() {
        anyhow::bail!("No valid lines found in input");
    }

    Ok(lines)
}

// Test async functionality
async fn fetch_data(url: &str) -> Result<String> {
    // This is just a mock function
    tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    Ok(format!("Fetched data from {}", url))
}

// Test pattern matching and destructuring
fn analyze_option(opt: Option<i32>) -> String {
    match opt {
        Some(x) if x > 0 => format!("Positive: {}", x),
        Some(x) if x < 0 => format!("Negative: {}", x),
        Some(0) => "Zero".to_string(),
        None => "Nothing".to_string(),
    }
}

// Test lifetime annotations
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() {
        x
    } else {
        y
    }
}

// Test generic constraints
fn print_hash<T: std::fmt::Debug + std::hash::Hash>(t: &T) {
    println!("{:?}", t);
}

// Test closures and iterators
fn demonstrate_iterators() {
    let numbers = vec![1, 2, 3, 4, 5];

    // Rustaceanvim should show closure parameter types
    let squared: Vec<i32> = numbers
        .iter()
        .map(|&x| x * x)
        .filter(|&x| x > 5)
        .collect();

    println!("Squared numbers > 5: {:?}", squared);
}

// Test trait implementation
trait Greet {
    fn greet(&self) -> String;
}

impl Greet for Person {
    fn greet(&self) -> String {
        format!("Hello, my name is {}", self.name)
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Test CLI parsing
    for _ in 0..cli.count {
        if let Some(name) = cli.name.as_deref() {
            println!("Hello, {}!", name);
        } else {
            println!("Hello, World!");
        }
    }

    // Test command handling
    match &cli.command {
        Some(Commands::Process { input }) => {
            println!("Processing file: {}", input);
            // Test error propagation
            let sample_data = "line1\nline2\n\nline3";
            let processed = process_data(sample_data)?;
            println!("Processed {} lines", processed.len());
        }
        Some(Commands::Analyze { verbose }) => {
            if *verbose {
                println!("Running verbose analysis...");
            } else {
                println!("Running analysis...");
            }
        }
        None => {
            // Test struct creation and methods
            let person = Person::new("Alice", 30)
                .with_email("alice@example.com");

            println!("{}", person.greet());

            // Test serialization
            let json = serde_json::to_string_pretty(&person)?;
            println!("Person as JSON:\n{}", json);

            // Test async
            let data = fetch_data("https://example.com").await?;
            println!("{}", data);

            // Test iterators
            demonstrate_iterators();

            // Test the macro-generated function
            generated_function();
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_person_creation() {
        let person = Person::new("Bob", 25);
        assert_eq!(person.name, "Bob");
        assert_eq!(person.age, 25);
        assert!(person.email.is_none());
    }

    #[test]
    fn test_analyze_option() {
        assert_eq!(analyze_option(Some(5)), "Positive: 5");
        assert_eq!(analyze_option(Some(-3)), "Negative: -3");
        assert_eq!(analyze_option(Some(0)), "Zero");
        assert_eq!(analyze_option(None), "Nothing");
    }

    #[test]
    fn test_longest() {
        assert_eq!(longest("short", "longer"), "longer");
        assert_eq!(longest("same", "same"), "same");
    }
}