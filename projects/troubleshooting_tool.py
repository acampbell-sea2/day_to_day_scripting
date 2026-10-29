#!/usr/bin/env python3
"""Menu and session foundation for the troubleshooting tool.

Connection verification and basic snapshot collection are menu placeholders.
"""

from datetime import datetime
from pathlib import Path
from urllib.parse import quote


OUTPUT_DIR = Path.home() / "troubleshooting-output"


def has_case_details(session):
    return bool(session["serial_number"] or session["jira_ticket"])


def set_case_details(session):
    """Replace the active identifiers together, preserving capitalization."""
    print("\nEnter the identifiers for this case.")
    print("Leave one blank if unused. Both blank keeps the current details.")

    serial_number = input("Serial number (case-sensitive): ").strip()
    jira_ticket = input("Jira ticket number: ").strip()

    if not (serial_number or jira_ticket):
        print("At least one identifier is required. Current details unchanged.")
        return

    session.update(serial_number=serial_number, jira_ticket=jira_ticket)
    print("Case details updated for this session.")


def save_output(session, action, output):
    """Save real action output using the current case identifiers."""
    if not has_case_details(session):
        raise ValueError("Enter a serial number or Jira ticket before saving.")

    parts = []
    for label, key in (("SN", "serial_number"), ("JIRA", "jira_ticket")):
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
        report.write(f"Action: {action}\n")
        report.write(f"Collected at: {now.isoformat(timespec='seconds')}\n\n")
        report.write(output)
        if not output.endswith("\n"):
            report.write("\n")

    return output_path


def verify_node(session):
    """Add the node connection and identity checks here in the next step."""
    print("\nNode connection verification and identity: not implemented yet.")
    # Once real output exists, use:
    # save_output(session, "node_identity", collected_output)


def basic_snapshot(session):
    """Add basic snapshot collection here in a later step."""
    print("\nBasic snapshot: not implemented yet.")
    # Once real output exists, use:
    # save_output(session, "basic_snapshot", collected_output)


def main():
    # Create the session once, before the loop. Nothing reloads it from disk.
    session = {"serial_number": "", "jira_ticket": ""}

    while True:
        print("\nTroubleshooting Tool")
        print(f"Serial number: {session['serial_number'] or '(not set)'}")
        print(f"Jira ticket: {session['jira_ticket'] or '(not set)'}")
        print("\n1. Enter or replace serial number / Jira ticket")
        print("2. Node connection verification and identity")
        print("3. Basic snapshot")
        print("0. Exit")

        choice = input("\nSelect an option: ").strip()

        if choice == "0":
            print("Exiting the troubleshooting tool.")           
            break
        elif choice == "1":
            set_case_details(session)
        elif choice in ("2", "3"):
            if not has_case_details(session):
                print("Choose option 1 and enter a serial number or Jira ticket first.")
                continue

            if choice == "2":
                verify_node(session)
            else:
                basic_snapshot(session)
        else:
            print("Invalid selection. Choose 0, 1, 2, or 3.")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        print("\nExiting the troubleshooting tool.")
