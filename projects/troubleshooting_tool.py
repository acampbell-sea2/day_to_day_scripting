
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
