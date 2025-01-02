def display_urls():
    """
    Displays the URLs with their IPs and ports for accessing the web interfaces.
    """
    urls = {
        "Wazuh": "https://<IP_ADDRESS>:5601 (Kibana)",
        "Graylog": "http://<IP_ADDRESS>:9000",
        "Shuffle": "https://<IP_ADDRESS>:3443",
        "DFIR-IRIS": "https://<IP_ADDRESS>",
    }

    banner = """
    =============================================================
                       Web Interface Access
    =============================================================
    """
    print(banner)

    for tool, url in urls.items():
        print(f"  - {tool} : {url}")

    print("\nReplace <IP_ADDRESS> with the configured IP address.\n")
    print("=============================================================")

