# Code Execution with MCP: Building More Efficient AI Agents

## Overview

Published November 4, 2025 by Adam Jones and Conor Kelly

This article explores how code execution enables AI agents to interact with Model Context Protocol (MCP) servers more efficiently, reducing token consumption by up to 98.7% compared to traditional direct tool-calling approaches.

## The Problem: Context Inefficiency at Scale

### Tool Definitions Overload Context

As developers connect agents to hundreds or thousands of tools via MCP, loading all tool definitions upfront creates significant overhead. Each tool description consumes tokens before the model even processes user requests, leading to delays and increased costs.

### Intermediate Results Multiply Token Usage

When agents directly call MCP tools, every result flows through the model's context window. For example, retrieving a document from Google Drive and then attaching it to Salesforce means the full content passes through the context twice—multiplying token consumption for large documents.

## The Solution: Present Tools as Code APIs

Rather than exposing MCP servers through direct tool calls, the approach treats them as code libraries. Agents discover tools by exploring a filesystem structure:

```
servers/
├── google-drive/
│   ├── getDocument.ts
│   └── index.ts
├── salesforce/
│   ├── updateRecord.ts
│   └── index.ts
```

This enables agents to load only needed tool definitions and process data in the execution environment before returning filtered results to the model.

## Key Benefits

### Progressive Disclosure
Models can navigate filesystems and request tool definitions on-demand rather than loading everything upfront, conserving context significantly.

### Context-Efficient Data Handling
Large datasets can be filtered, aggregated, or transformed within the execution environment. When retrieving 10,000 spreadsheet rows, agents filter results locally and return only relevant data.

### Improved Control Flow
Loops, conditionals, and error handling use familiar code patterns, reducing latency from waiting for model evaluations between operations.

### Privacy Protection
Intermediate results remain in the execution environment by default. Sensitive data can be tokenized automatically, preventing personally identifiable information from entering the model's context.

### State Persistence
Agents can maintain progress across operations by writing to files, enabling resumable workflows and developing reusable skills for future tasks.

## Implementation Considerations

Code execution introduces infrastructure complexity requiring secure sandboxing, resource limits, and monitoring. These operational costs must be weighed against efficiency gains.

## Conclusion

MCP provides protocol standardization for agent-tool connections. Code execution applies established software engineering patterns to agents, enabling them to handle tool composition, context management, and state persistence more effectively—encouraging developers to share findings with the MCP community.
