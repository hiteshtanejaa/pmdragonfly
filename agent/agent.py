"""Simple ADK hello-world agent."""

from google.adk.agents import Agent
from google.adk.tools import FunctionTool


def say_hello(name: str = "world") -> str:
    """Return a greeting for the given name."""
    return f"Hello, {name}!"


root_agent = Agent(
    name="hello_agent",
    model="gemini-2.5-flash",
    description="A simple hello-world agent that greets users by name.",
    instruction="You are a friendly greeter. When the user provides a name, call the say_hello tool and return its result.",
    tools=[FunctionTool(say_hello)],
)
