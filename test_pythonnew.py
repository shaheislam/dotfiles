def greet(name):
    """Return a greeting message."""
    return f"Hi, {name}!"


class Counter:
    """A simple counter class."""

    def __init__(self, start=0):
        self.value = start

    def increment(self):
        self.value += 1

    def decrement(self):
        self.value -= 1

    def __str__(self):
        return f"Counter({self.value})"


if __name__ == "__main__":
    print(greet("World"))
    print(f"2 + 3 = {add(2, 3)}")

    counter = Counter()
    counter.increment()
    counter.increment()
    print(counter)
