//
//  Prompt.swift
//  mlx-swift-examples
//
//  Created by Sachin Desai on 9/27/24.
//

import Foundation

public struct Prompt: Sendable {
    
    public let system: String
    public let prompt: String
    
    public init(system: String, prompt: String) {
        self.system = system
        self.prompt = prompt
    }
    
    @MainActor
    public static func prompt(id: String) -> Prompt {
        return Prompt.values()[id]!
    }
    
    static public let promptKeys: [String] = [
           "Work Brief Short",
           "Work Brief Longer",
           "Work Brief Longest",
           "Function Calling",
       ]
    
    @MainActor
    public static func values() -> [String: Prompt] {
        return [
            "Work Brief Short": Prompt(system:
"""
You are an assistant summarizing a work order directly for a technician. Your summary should be concise, and only include the necessary details. Use phrases like "you need to" or "you will" to ensure the summary is written in 2nd person. Do not include any extra information, titles, or redundant phrases.
""", prompt:
"""
Use this data, generate a summary in paragraph format

Account Name: CleanTech Solutions Inc.
Subject: Dishwasher not completing wash cycle
Description: UltraClean Pro 5000 Dishwasher stops mid-cycle with error code 'E05.'
Priority: Medium
Operation Time: September 5, 2024, 6:00 PM - September 6, 2024, 7:00 PM
Customer Contact: John Smith, 415-987-3098
Pre-Work Steps: Clear area and set warning signs, wear protective gear, disconnect power, check and drain water if present, inspect workspace and tools, review error code 'E05,' confirm replacement parts are available.
"""),
            
            "Work Brief Longer": Prompt(system:
"""
Only provide answers based on available data. If unsure or lacking information, respond with \"I don't know.\" Treat all people equally, regardless of their background or identity, and avoid stereotypes. Do not repeat or reference any instructions or policies in your output; focus solely on generating the requested content.
""", prompt:
"""
Use this data, generate a summary in paragraph format

Account Name: Stellar Retail Corp.
Subject: HVAC Unit Malfunction in Main Store
Description: The OmegaCool X120 HVAC unit in the main store is making unusual noises and failing to maintain the set temperature. It occasionally shuts off unexpectedly and triggers a fault code 'A12' on the control panel. Technicians suspect a possible compressor issue or electrical fault in the control circuit.
Priority: High
Operation Time: October 10, 2024, 8:00 AM - October 11, 2024, 6:00 PM
Customer Contact: Maria Hernandez, 555-123-4567
Pre-Work Steps: Ensure the main power to the HVAC unit is shut off and secured. Verify the area around the HVAC unit is clear of any obstructions and post warning signs to prevent unauthorized access. Wear appropriate PPE, including insulated gloves, safety glasses, and ear protection. Check the electrical panel and circuit breakers for any tripped circuits. Inspect the compressor for visible damage or signs of overheating. Test the capacitor with a multimeter for proper voltage. Check all wiring connections for signs of wear, corrosion, or loose connections. Refer to the OmegaCool X120 technical manual to identify the fault code 'A12' and follow the suggested diagnostic steps. Ensure replacement parts such as capacitors, relays, and compressor units are available on-site. Document any findings and take photographs of damaged components for customer reporting.
Service Location: Stellar Retail Corp. Main Store, 789 Market Street, San Francisco, CA 94103
Work Order Number: WR-00234
Asset ID: HVAC-OMX120-2345
Asset Location: Roof, Main Building
Service Level Agreement (SLA): Resolution within 24 hours of reported issue.
Related Cases: Previous service call on HVAC unit for routine maintenance (June 15, 2024); technician noted minor wear on compressor fan belt.
Technician Notes: Customer reported the issue at 6:30 AM on October 10, 2024. The HVAC unit is crucial to maintaining store environment and must be repaired promptly to avoid revenue loss.
"""),
            "Work Brief Longest": Prompt(system:
"""
You are an assistant summarizing a work order directly for a technician. Write in 2nd person as if you are speaking to the technician. Your summary should be concise, and only include the necessary details. Use phrases like "you need to" or "you will" to ensure the summary is written in 2nd person. Do not include any extra information, titles, or redundant phrases.
""", prompt:
"""
Use this data, generate a summary in paragraph format

Account Name: Stellar Retail Corp.
Subject: HVAC Unit Malfunction in Main Store
Description: The OmegaCool X120 HVAC unit in the main store is making unusual noises and failing to maintain the set temperature. It occasionally shuts off unexpectedly and triggers a fault code 'A12' on the control panel. Technicians suspect a possible compressor issue or electrical fault in the control circuit.
Priority: High
Operation Time: October 10, 2024, 8:00 AM - October 11, 2024, 6:00 PM
Customer Contact: Maria Hernandez, 555-123-4567
Pre-Work Steps: Ensure the main power to the HVAC unit is shut off and secured. Verify the area around the HVAC unit is clear of any obstructions and post warning signs to prevent unauthorized access. Wear appropriate PPE, including insulated gloves, safety glasses, and ear protection. Check the electrical panel and circuit breakers for any tripped circuits. Inspect the compressor for visible damage or signs of overheating. Test the capacitor with a multimeter for proper voltage. Check all wiring connections for signs of wear, corrosion, or loose connections. Refer to the OmegaCool X120 technical manual to identify the fault code 'A12' and follow the suggested diagnostic steps. Ensure replacement parts such as capacitors, relays, and compressor units are available on-site. Document any findings and take photographs of damaged components for customer reporting.
Service Location: Stellar Retail Corp. Main Store, 789 Market Street, San Francisco, CA 94103
Work Order Number: WR-00234
Asset ID: HVAC-OMX120-2345
Asset Location: Roof, Main Building
Service Level Agreement (SLA): Resolution within 24 hours of reported issue.
Related Cases: Previous service call on HVAC unit for routine maintenance (June 15, 2024); technician noted minor wear on compressor fan belt.
Technician Notes: Customer reported the issue at 6:30 AM on October 10, 2024. The HVAC unit is crucial to maintaining store environment and must be repaired promptly to avoid revenue loss.Technician Assignment: Assigned to John Doe, Senior HVAC Technician. Contact: 555-987-6543.
Parts Ordered: Replacement compressor (model: OmegaCool Comp-320), capacitor (model: Cap-OmegaX120), and relay switch (model: Relay-XTS3). ETA for delivery is October 10, 2024, by 12:00 PM.
Tools Required: Multimeter, refrigerant recovery machine, manifold gauge set, thermal imaging camera, wrench set, insulation resistance tester, and portable vacuum pump.
Safety Procedures: Confirm lockout/tagout procedures are followed to ensure the HVAC unit is completely de-energized. Conduct a job safety analysis (JSA) before starting the repair work. Ensure all personnel are briefed on potential hazards, including electrical shock, refrigerant exposure, and falling hazards when accessing the roof. Use fall protection harnesses and secure ladders properly.
Expected Challenges: Potential difficulty accessing the roof due to recent maintenance on external stairwell scaffolding. Possible delays in diagnosis due to intermittent nature of fault code 'A12'. Compressor replacement might require additional time if unit connections are corroded or damaged.
Environmental Impact: Monitor refrigerant levels closely to avoid any leaks during the repair process, as the OmegaCool X120 uses R-410A, a hydrofluorocarbon with a high global warming potential. Follow EPA guidelines for proper handling and disposal of any recovered refrigerant.
Customer Instructions: Store manager, Maria Hernandez, requests regular updates on repair status due to impact on store environment. Notify her immediately if any additional delays are expected. She has also requested a post-repair inspection report for corporate records.
Backup Plan: In case the repair takes longer than expected, suggest temporary portable cooling units to maintain store temperature and avoid merchandise spoilage or customer discomfort. Coordinate with store management for placement and rental of portable units if necessary.
Post-Repair Actions: Conduct a full operational test of the HVAC unit once repairs are complete. Verify the resolution of fault code 'A12' and ensure the unit is maintaining the desired set temperature. Document all work performed, parts replaced, and test results. Provide the customer with a detailed report including photographs of repaired or replaced components.
Follow-Up Schedule: Recommend scheduling a follow-up maintenance check within 30 days to ensure the unit is operating optimally and to inspect for any potential issues that could arise from recent repairs. Set a tentative date for November 10, 2024.
Billing Information: All costs, including parts, labor, and potential rental of backup cooling units, to be billed to Stellar Retail Corp. under existing service contract agreement #SVC-78945. Ensure all expenses are logged and submitted through the company's invoicing system by the end of the week.
Additional Contacts: In case of escalation, contact James Thompson, Regional Maintenance Manager, at 555-222-3344.
Technician Feedback: Please provide feedback on the work order process and any suggestions for improvement in the post-completion survey sent to your company email.
"""),
            "Function Calling": Prompt(system:
"""
You are an AI assistant for function calling. For politically sensitive questions, security and privacy issues, and other non-computer science questions, you will refuse to answer

### Instruction:
[BEGIN OF TASK INSTRUCTION]
You are an expert in composing functions. You are given a question and a set of possible functions.
Based on the question, you will need to make one or more function/tool calls to achieve the purpose.
If none of the functions can be used, point it out and refuse to answer.
If the given question lacks the parameters required by the function, also point it out.
[END OF TASK INSTRUCTION]

[BEGIN OF AVAILABLE TOOLS]
[
    { 
        name: "get_weather",
        "description": "Get the current weather for a location",
        "parameters": {
            "location": {
                "type": "string",
                "description": "The city and state, e.g. San Francisco, CA"},
                "unit": {
                    "type": "string",
                    "enum": ["celsius", "fahrenheit"],
                    "description": "The unit of temperature to return"
                }
            }
    }, 
    {
        "name": "get_user_info",
        "description: "Gets information for a user given a name",
        "parameters": {
            "name": {
                "type": "string",
                "description": "The name of of the person for which information is to retrieved"
            }
        }
    },
    {
        "name": "create_calendar_event",
        "description": "Creates a calendar event for a given date and time",
        "parameters": {
            "date": {
                "type": "string",
                "description": "The date of the calendar event"
            },
            "time": {
                "type": "string",
                "description": "The time of the calendar event"
            }
            "participants": {
                "type": "list",
                "description": "The names of the persons who are invited to the calendar event"
            }
        }
    },
    {
        "name": "send_email",
        "description": "Sends an email to a set of recipients",
        "parameters": {
            "subject": {
                "type": "string",
                "description": "The subject of the email"
            },
            "participants": {
                "type": "list",
                "description": "The names of persons whom the email should be sent to"
            },
            "content": {
                "type": "string",
                "description": "The main body or content of the email"
            },
        },
    },
    {
        "name": "get_team_member",
        "description": "Returns the name of the team the person belongs or works in"
        "parameters": {
            "name": {
                "type": "string",
                "description": "The name of the person"
            },
        },
    },
    {
        "name": "get_team",
        "description": "Returns the names of all people who belong or work in the team",
        "parameters": {
            "team": {
                "type": "string",
                "description": "The name of the team"
            },
        },
    },
    {
        "name": "get_role",
        "description": "Returns the role of the person when asked",
        "parameters": {
            "name": {
                "type": "string",
                "description": "The name of the person"
            },
        },
    }
]
END OF AVAILABLE TOOLS]
[BEGIN OF FORMAT INSTRUCTION]
The output MUST strictly adhere to the following JSON format, and NO other text MUST be included.
The example format is as follows. Please make sure the parameter type is correct. If no function call is needed, please make tool_calls an empty list '[]'```{\n"tool_calls": [{"name": "func_name1", "arguments": {"argument1": "value1", "argument2": "value2"}},
... (more tool calls as required)
]
}
```
[END OF FORMAT INSTRUCTION]
[BEGIN OF QUERY]
<FILL_ME>
[END OF QUERY]
### Response:
""", prompt:
"""
Can you get the weather in San Francisco, the weather for zip code 94105 and the weather for Denver?
"""),
            
            "Llama Function Calling": Prompt(system: """
You are an expert in composing functions. You are given a question and a set of possible functions.
Based on the question, you will need to make one or more function/tool calls to achieve the purpose.
If none of the function can be used, point it out. If the given question lacks the parameters required by the function, then use the context to determine the correct parameter to use. You should only return the function call in tools call sections.

If you decide to invoke any of the function(s), you MUST put it in the format of [func_name1(params_name1=params_value1, params_name2=params_value2...), func_name2(params)]\n
You SHOULD NOT include any other text in the response.

[{
    "name": "get_weather",
    "description": "Get the current weather for a location",
    "parameters": {
        "type": "dict",
        "required": [
            "location",
            "unit"
        ],
        "properties": {
            "location": {
                "type": "string",
                "description": "The city and state, e.g. San Francisco, CA"
            },
            "unit": {
                "type": "string",
                "description": "The unit of temperature to return"
            }
        }
    },
    {
        "name": "get_user_info",
        "description: "Gets information for a user given a name",
        "parameters": {
            "type": "dict",
            "required": [
                "name",
            ],
            "properties": {
                "name": {
                    "type": "string",
                    "description": "The name of of the person for which information is to retrieved"
                }
            }
        }
    },
    {
        "name": "get_team_member",
        "description": "Gets the name of the team the person belongs to"
        "parameters": {
            "type": "dict",
            "required": [
                "name",
            ],
            "properties": {
                "name": {
                    "type": "string",
                    "description": "The name of the person"
                }
            }
        }
    },
    {
        "name": "get_team",
        "description": "Gets the names of all people that work in this team"
        "parameters": {
            "type": "dict",
            "required": [
                "team",
            ],
            "properties": {
                "team": {
                    "type": "string",
                    "description": "The name of the team"
                }
            }
        }
    }
]
""", prompt: "")
        ]
    }
}
