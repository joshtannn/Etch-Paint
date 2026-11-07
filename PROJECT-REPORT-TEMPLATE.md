# CPE 2300 Etch / Paint — Final Project Report

> Complete this report using your team’s actual implementation, test results, and contributions. Do not claim a test passed until you ran it. The workbook requires all submitted RISC-V assembly to be written by the team.

## 1. Cover

- **Project:** Etch / Paint
- **Team:** [team name]
- **Members:** [full names]
- **Repository:** [GitHub URL]
- **Course simulator:** [name/version]

## 2. Goals

### Core objectives

1. Poll the simulator’s supported pointer and keyboard inputs. **Status:** [met / partial / missed]
2. Map drawing input to valid framebuffer coordinates and render a brush mark. **Status:** [met / partial / missed]
3. Keep earlier marks visible while responding to new input. **Status:** [met / partial / missed]

### Add-ons

1. Keyboard-controlled color selection, if implemented. **Status:** [met / partial / missed / deferred]
2. Keyboard-controlled clear action (C, if supported; otherwise the team’s confirmed key). **Status:** [met / partial / missed / deferred]

## 3. Program flowchart

See [the flowchart](flowchart.mmd). Update it if the implemented control flow differs.

## 4. Work division

| Member | Routines/features personally written | Testing, documentation, or integration |
|---|---|---|
| [Name 1] | [actual work] | [actual work] |
| [Name 2] | [actual work] | [actual work] |
| [Name 3] | [actual work] | [actual work] |

## 5. Progress on each goal

| Goal | Met / partial / missed | Evidence (commit, test, screenshot) |
|---|---|---|
| Core 1 | [status] | [evidence] |
| Core 2 | [status] | [evidence] |
| Core 3 | [status] | [evidence] |
| Add-on 1 | [status] | [evidence] |
| Add-on 2 | [status] | [evidence] |

## 6. How it works

Describe the actual input-polling routine, coordinate mapping, drawing routine, framebuffer behavior, and main loop. Name the subroutines your team wrote and explain each one in your own words.

## 7. How to build and run

- Source file: `[team-authored filename].s`
- Assembler / Playground steps: [exact steps used in class]
- Simulator setup or input configuration: [actual settings]

The final submission must contain one `.s` file that assembles and runs in the course Playground.

## 8. Test results

| Scenario | Input/action | Expected result | Actual result | Pass/fail |
|---|---|---|---|---|
| Idle input | [actual setup] | No new mark is drawn | [record result] | [pass/fail] |
| Center mark | [actual supported pointer action] | Mark appears at the selected position | [record result] | [pass/fail] |
| Boundary marks | [actual corner actions] | Marks stay inside the framebuffer | [record result] | [pass/fail] |
| Multiple marks | [draw and release several times] | Earlier marks remain visible | [record result] | [pass/fail] |
| Clear add-on | [confirmed key, if implemented] | Existing marks clear; new mark can be drawn | [record result] | [pass/fail/not implemented] |

## 9. Screenshots

Add screenshots of the program running in the course simulator. Include captions that identify the tested scenario.

## 10. Challenges and lessons learned

- **Challenges / what did not work:** [actual issues]
- **How the team addressed them:** [actual steps]
- **Lessons learned:** [what you would change or reuse]
