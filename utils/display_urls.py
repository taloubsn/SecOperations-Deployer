def display_urls():
    """
    Affiche les URLs avec leurs IPs et ports pour l'accès aux interfaces web.
    """
    urls = {
        "Wazuh": "https://<IP_ADDRESS>:5601 (Kibana)",
        "Graylog": "http://<IP_ADDRESS>:9000",
        "MISP": "http://<IP_ADDRESS>:4433 (HTTPS)",
        "Shuffle": "https://<IP_ADDRESS>:3443",
        "DFIR-IRIS": "https://<IP_ADDRESS>",
    }
    
    banner = """
    =============================================================
                       Accès aux Interfaces Web
    =============================================================
    """
    print(banner)
    
    for tool, url in urls.items():
        print(f"  - {tool} : {url}")
    
    print("\nRemplacez <IP_ADDRESS> par l'adresse IP configurée.\n")
    print("=============================================================")

