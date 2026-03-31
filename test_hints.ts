// TypeScript file to test inlay hints functionality

// Variable type inference - hints show inferred types
const userName = "Alice";
const userAge = 25;
const scores = [95, 87, 92, 88, 91];
const config = {
  debug: true,
  timeout: 3000,
  retries: 5,
  endpoint: "https://api.example.com"
};

// Function with multiple parameters - hints show parameter names
function processUser(
  name: string,
  age: number,
  active: boolean,
  rating: number,
  scores: number[]
): string {
  const average = scores.reduce((a, b) => a + b, 0) / scores.length;
  return `User: ${name}, Age: ${age}, Active: ${active}, Rating: ${rating}, Avg: ${average}`;
}

// Call with literals - hints show parameter names
const result = processUser("Bob", 30, true, 4.5, [80, 85, 90]);
console.log(result);

// Arrow functions with type inference
const multiply = (x: number, y: number) => x * y;
const calculate = (a: number, b: number) => multiply(a, b) * 2;
const calculation = calculate(5, 10);

// Generic function with type inference
function identity<T>(value: T): T {
  return value;
}

const stringValue = identity("hello");
const numberValue = identity(42);
const objectValue = identity({ key: "value" });

// Array methods with inferred callbacks
const doubled = scores.map(score => score * 2);
const filtered = doubled.filter(score => score > 180);
const sum = filtered.reduce((acc, curr) => acc + curr, 0);

// Object destructuring with type inference
const { debug, timeout, retries } = config;
console.log(`Debug: ${debug}, Timeout: ${timeout}, Retries: ${retries}`);

// Promise chains with type inference
async function fetchData(url: string): Promise<{ data: string; status: number }> {
  return { data: "sample data", status: 200 };
}

fetchData(config.endpoint)
  .then(response => response.data)
  .then(data => data.toUpperCase())
  .then(processed => console.log(processed));

// Async/await with type inference
async function processAsync() {
  const response = await fetchData(config.endpoint);
  const processed = response.data.toUpperCase();
  return processed;
}

// Complex interface with nested types
interface User {
  id: number;
  name: string;
  email: string;
  profile: {
    bio: string;
    avatar: string;
    preferences: {
      theme: "light" | "dark";
      notifications: boolean;
    };
  };
}

const user: User = {
  id: 1,
  name: "Alice",
  email: "alice@example.com",
  profile: {
    bio: "Software Developer",
    avatar: "avatar.png",
    preferences: {
      theme: "dark",
      notifications: true
    }
  }
};

// Class with methods and type inference
class DataProcessor<T> {
  private data: T[];

  constructor(initialData: T[]) {
    this.data = initialData;
  }

  add(item: T): void {
    this.data.push(item);
  }

  process(callback: (item: T) => T): T[] {
    return this.data.map(callback);
  }

  filter(predicate: (item: T) => boolean): T[] {
    return this.data.filter(predicate);
  }
}

const numberProcessor = new DataProcessor([1, 2, 3, 4, 5]);
const processedNumbers = numberProcessor.process(n => n * 2);
const filteredNumbers = numberProcessor.filter(n => n > 2);

// Union and literal types
type Status = "pending" | "success" | "error";
type Theme = "light" | "dark" | "auto";

function handleStatus(status: Status, retryCount: number = 3) {
  switch (status) {
    case "pending":
      console.log("Loading...");
      break;
    case "success":
      console.log("Complete!");
      break;
    case "error":
      if (retryCount > 0) {
        console.log(`Retrying... ${retryCount} attempts left`);
      }
      break;
  }
}

handleStatus("pending");
handleStatus("error", 5);

// Tuple types with destructuring
type Point3D = [x: number, y: number, z: number];
const point: Point3D = [10, 20, 30];
const [x, y, z] = point;

// Enum with values
enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3
}

function log(message: string, level: LogLevel = LogLevel.INFO) {
  console.log(`[${LogLevel[level]}] ${message}`);
}

log("Application started");
log("An error occurred", LogLevel.ERROR);

// Optional chaining and nullish coalescing
interface Settings {
  theme?: {
    primary?: string;
    secondary?: string;
  };
  timeout?: number;
}

const settings: Settings = {
  theme: {
    primary: "#007bff"
  }
};

const primaryColor = settings.theme?.primary ?? "#000000";
const secondaryColor = settings.theme?.secondary ?? "#666666";
const timeoutValue = settings.timeout ?? 5000;

// Rest parameters
function sum(...numbers: number[]): number {
  return numbers.reduce((a, b) => a + b, 0);
}

const total = sum(1, 2, 3, 4, 5);
const numbers = [1, 2, 3] as const;
const moreNumbers = [...numbers, 4, 5];

// Export for module demonstration
export { User, DataProcessor, processUser, Status };
