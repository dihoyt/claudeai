# Lunch & Learn: Building Better Agent Prompts with AI

This guide demonstrates how to leverage AI to build effective agent prompts that automate and enhance common workplace tasks. Learn by example with real-world use cases integrated with Microsoft 365 tools.

## <¯ What You'll Learn

- **Prompt Engineering Fundamentals**: Core principles for creating effective AI agent prompts
- **Task Automation**: How to design prompts for specific workplace scenarios
- **Integration Patterns**: Working with MS Outlook, OneDrive, and SharePoint
- **Iterative Improvement**: Testing and refining prompts for better results

## =Ú Agent Prompt Examples

This folder contains practical agent prompt templates for common workplace tasks:

### 1. [Project Scoping Agent](prompts/project-scoping.md)
Analyzes project requirements, identifies stakeholders, estimates scope, and generates comprehensive project documentation.

**Key Features:**
- Requirements gathering and analysis
- Stakeholder identification
- Scope definition and boundaries
- Risk assessment
- Timeline estimation

### 2. [IT Environmental Reviews Agent](prompts/it-environmental-reviews.md)
Conducts thorough reviews of IT infrastructure, applications, and environments to assess health, security, and compliance.

**Key Features:**
- System inventory and documentation
- Security posture assessment
- Compliance checking
- Performance analysis
- Recommendation generation

### 3. [Daily Activity Agent](prompts/daily-activity.md)
Integrates with MS Outlook and OneDrive/SharePoint to summarize your daily activities, meetings, and document work.

**Key Features:**
- Calendar analysis and meeting summaries
- Email activity categorization
- Document changes tracking
- Time allocation insights
- Activity report generation

### 4. [Suggested Work Agent](prompts/suggested-work.md)
Analyzes your calendar, emails, and tasks to intelligently suggest what to work on next based on priorities, deadlines, and context.

**Key Features:**
- Priority-based task recommendations
- Context-aware scheduling
- Deadline management
- Meeting preparation suggestions
- Work-life balance insights

## =€ Getting Started

### Step 1: Understanding the Prompt Structure

Each agent prompt follows a consistent structure:

```markdown
# Agent Name

## Purpose
[Clear statement of what the agent does]

## Context
[Information the agent needs to operate effectively]

## Instructions
[Step-by-step guidance for the agent]

## Output Format
[Expected structure of the agent's response]

## Examples
[Sample inputs and outputs]
```

### Step 2: Choosing the Right Agent

Select an agent based on your task:

- **Planning a new project?** ’ Use Project Scoping Agent
- **Auditing systems or infrastructure?** ’ Use IT Environmental Reviews Agent
- **Need a daily summary?** ’ Use Daily Activity Agent
- **Not sure what to work on?** ’ Use Suggested Work Agent

### Step 3: Running an Agent

#### Using Claude Code CLI

```bash
# Run with a specific prompt file
claude-code -p "Lunch & Learn/prompts/project-scoping.md" -i "Project: Migrate CRM to cloud"
```

#### Using Claude.ai

1. Copy the prompt from the relevant file
2. Paste into a new conversation
3. Provide the required context/inputs
4. Review and refine the output

#### Using Claude API

```python
import anthropic

client = anthropic.Anthropic(api_key="your-api-key")

# Load your prompt
with open("prompts/project-scoping.md", "r") as f:
    prompt = f.read()

# Add your specific input
user_input = "Project: Implement zero-trust security model"

message = client.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=4096,
    messages=[
        {"role": "user", "content": f"{prompt}\n\nInput: {user_input}"}
    ]
)

print(message.content)
```

## =' Customizing Prompts

### Tips for Adaptation

1. **Add Your Context**: Include company-specific terminology, processes, or standards
2. **Adjust Output Format**: Modify templates to match your documentation style
3. **Add Constraints**: Include budget limits, timeline requirements, or resource constraints
4. **Include Examples**: Add your own examples for better results
5. **Iterate**: Test and refine based on actual outputs

### Example Customization

Original prompt section:
```markdown
## Output Format
Provide a summary in bullet points.
```

Customized version:
```markdown
## Output Format
Provide a summary following our standard report template:
- Executive Summary (2-3 sentences)
- Key Findings (bullet points)
- Action Items (numbered list with owners)
- Next Steps (timeline-based)
```

## = Microsoft 365 Integration

The Daily Activity and Suggested Work agents assume integration with Microsoft 365 services. Here's how they work:

### Required Permissions

- **MS Outlook**: Calendar read, Email read
- **OneDrive/SharePoint**: Files read, Activity tracking

### Integration Methods

1. **MCP Server**: Use Microsoft Graph API MCP server (see [../mcps/microsoft-graph/](../mcps/microsoft-graph/))
2. **Power Automate**: Create flows that pass data to Claude
3. **Graph API Direct**: Query Graph API and include results in prompts

### Sample Data Flow

```
MS Outlook Calendar ’ Graph API ’ Agent Prompt ’ Claude ’ Summary Report
```

## =Ö Prompt Engineering Best Practices

### 1. Be Specific
L "Analyze this project"
 "Analyze this project's technical requirements, identify potential risks, and estimate timeline with milestones"

### 2. Provide Context
Include relevant background information:
- Company/team context
- Existing systems or constraints
- Success criteria
- Stakeholder information

### 3. Define Output Structure
Clear output formats lead to consistent, usable results:
- Use templates
- Specify format (markdown, JSON, etc.)
- Include required sections
- Provide examples

### 4. Include Examples
Show the agent what good looks like:
- Input examples
- Expected output examples
- Edge cases

### 5. Iterate and Refine
- Start simple, add complexity gradually
- Test with real data
- Gather feedback from users
- Version your prompts

## <“ Learning Path

### Beginner
1. Start with the Daily Activity Agent
2. Run it with sample calendar data
3. Observe the output and identify improvements

### Intermediate
1. Customize the Project Scoping Agent for your domain
2. Add company-specific templates
3. Test with a real project

### Advanced
1. Create a new agent prompt from scratch
2. Integrate with your own tools/APIs
3. Build multi-step workflows combining multiple agents

## =Ý Exercise: Build Your First Prompt

Try creating a prompt for a task in your workflow:

**Template:**
```markdown
# [Your Agent Name]

## Purpose
[What problem does this solve?]

## Context
What information do you need to provide:
- [ ] Item 1
- [ ] Item 2
- [ ] Item 3

## Instructions
1. [First step]
2. [Second step]
3. [Final step]

## Output Format
[Describe the expected output]

## Example Input
[Provide a sample input]

## Example Output
[Show what the result should look like]
```

## = Troubleshooting

### Prompt Not Working as Expected?

1. **Too vague?** Add more specific instructions
2. **Inconsistent results?** Add examples and constraints
3. **Wrong format?** Specify output structure more clearly
4. **Missing context?** Include relevant background information

### Common Issues

| Issue | Solution |
|-------|----------|
| Generic outputs | Add specific examples and constraints |
| Hallucinated data | Emphasize using only provided information |
| Wrong format | Use templates and explicit structure |
| Too verbose | Add length limits and prioritization guidance |

## =Ú Additional Resources

- [Anthropic Prompt Engineering Guide](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering)
- [Claude Code Documentation](https://github.com/anthropics/claude-code)
- [Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)

## > Contributing Your Own Prompts

Have a great agent prompt? Share it!

1. Add your prompt to the `prompts/` directory
2. Follow the standard structure
3. Include examples and documentation
4. Update this README with a description

## =¡ Next Steps

1. Review the example prompts in the [prompts/](prompts/) directory
2. Choose one that matches your needs
3. Customize it for your context
4. Test it with real data
5. Share your results and improvements

---

**Workshop Duration**: 45-60 minutes
**Skill Level**: All levels welcome
**Prerequisites**: Basic understanding of AI/LLMs helpful but not required

Happy prompting! =€
