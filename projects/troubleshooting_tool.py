#!/usr/bin/env python3
"""Menu and session foundation for the troubleshooting tool.

Connection verification and basic snapshot collection are menu placeholders.
"""

import subprocess
import sys
from datetime import datetime
from pathlib import Path
from shutil import get_terminal_size
from textwrap import wrap
from urllib.parse import quote


OUTPUT_DIR = Path.home() / "troubleshooting-output"


def clear_screen():
    """Clear an interactive WSL/Linux terminal."""
    if not sys.stdout.isatty():
        return

    try:
        subprocess.run(["clear"], check=False, stderr=subprocess.DEVNULL)
    except OSError:
        # The menu can still run if the clear command is unavailable.
        pass


def pause():
    """Keep action results visible until the user is ready."""
    input("\nPress Enter to return to the menu...")


def print_box(title, lines=()):
    """Draw a box that wraps long text; None adds a horizontal divider."""
    terminal_width = get_terminal_size(fallback=(80, 24)).columns
    width = max(1, min(64, terminal_width - 4))
    border = "=" * (width + 4)

    print(border)
    for line in wrap(title, width=width) or [""]:
        print(f"| {line:^{width}} |")
    print(border)

    for line in lines:
        if line is None:
            print(border)
            continue

        for wrapped_line in wrap(line, width=width) or [""]:
            print(f"| {wrapped_line:<{width}} |")

    if lines:
        print(border)


def has_case_details(session):
    """A serial number or Jira ticket is required; hostname is optional."""
    return bool(session["serial_number"] or session["jira_ticket"])


def set_case_details(session):
    """Replace the active identifiers together, preserving capitalization."""
    clear_screen()
    print_box(
        "Case Details",
        [
            "Provide a serial number or Jira ticket.",
            "Hostname is optional.",
            "",
            "Accepted updates replace all three fields.",
            "Blank fields clear their previous values.",
        ],
    )
    print()

    serial_number = input("Serial number (case-sensitive): ").strip()
    jira_ticket = input("Jira ticket number: ").strip()
    hostname = input("Hostname (example: gpu0143.o1.local): ").strip()

    if not (serial_number or jira_ticket):
        print("A serial number or Jira ticket is required. Current details unchanged.")
        return

    session.update(
        serial_number=serial_number,
        jira_ticket=jira_ticket,
        hostname=hostname,
    )
    print("Case details updated for this session.")


def save_output(session, action, output):
    """Save real action output using the current case identifiers."""
    if not has_case_details(session):
        raise ValueError("Enter a serial number or Jira ticket before saving.")

    parts = []
    for label, key in (
        ("SN", "serial_number"),
        ("JIRA", "jira_ticket"),
        ("HOST", "hostname"),
    ):
        if session[key]:
            # Encode filename separators while keeping letter case intact.
            parts.append(f"{label}_{quote(session[key], safe='-_.')}")

    now = datetime.now().astimezone()
    parts.append(quote(action, safe="-_."))
    parts.append(now.strftime("%Y%m%d_%H%M%S_%f%z"))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / ("__".join(parts) + ".txt")

    # Exclusive creation prevents an existing report from being overwritten.
    with output_path.open("x", encoding="utf-8") as report:
        report.write(f"Serial number: {session['serial_number'] or '(not provided)'}\n")
        report.write(f"Jira ticket: {session['jira_ticket'] or '(not provided)'}\n")
        report.write(f"Hostname: {session['hostname'] or '(not provided)'}\n")
        report.write(f"Action: {action}\n")
        report.write(f"Collected at: {now.isoformat(timespec='seconds')}\n\n")
        report.write(output)
        if not output.endswith("\n"):
            report.write("\n")

    return output_path


def verify_node(session):
    """Add the node connection and identity checks here in the next step."""
    clear_screen()
    print_box("Node Connection Verification and Identity")
    print("\nNode connection verification and identity: not implemented yet.")
    # Once real output exists, use:
    # save_output(session, "node_identity", collected_output)


def basic_snapshot(session):
    """Add basic snapshot collection here in a later step."""
    clear_screen()
    print_box("Basic Snapshot")
    print("\nBasic snapshot: not implemented yet.")
    # Once real output exists, use:
    # save_output(session, "basic_snapshot", collected_output)


def main():
    # Create the session once, before the loop. Nothing reloads it from disk.
    session = {
        "serial_number": "",
        "jira_ticket": "",
        "hostname": "",
    }

    while True:
        clear_screen()
        print_box(
            "Troubleshooting Tool",
            [
                f"Serial number: {session['serial_number'] or '(not set)'}",
                f"Jira ticket: {session['jira_ticket'] or '(not set)'}",
                f"Hostname: {session['hostname'] or '(not set)'}",
                None,
                "1. Enter or replace serial number / Jira ticket / hostname",
                "2. Node connection verification and identity",
                "3. Basic snapshot",
                "0. Exit",
            ],
        )

        choice = input("\nSelect an option: ").strip()

        if choice == "0":
            print("Exiting the troubleshooting tool.")
            break
        elif choice == "1":
            set_case_details(session)
        elif choice in ("2", "3"):
            if not has_case_details(session):
                print("Choose option 1 and enter a serial number or Jira ticket first.")
            elif choice == "2":
                verify_node(session)
            else:
                basic_snapshot(session)
        else:
            print("Invalid selection. Choose 0, 1, 2, or 3.")

        pause()


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        print("\nExiting the troubleshooting tool.")
