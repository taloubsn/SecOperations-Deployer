# Mapping table for custom messages
SCRIPT_MESSAGES = {
    "utils/docker-install.sh": {
        "start": "� Installing Docker...",
        "success": "✅ Docker installation completed successfully.",
        "failure": "❌ Docker installation failed."
    },
    "wazuh/install.sh": {
        "start": "� Installing Wazuh...",
        "success": "✅ Wazuh installation completed successfully.",
        "failure": "❌ Wazuh installation failed."
    },
    "wazuh/config.sh": {
        "start": "� Configuring Wazuh...",
        "success": "✅ Wazuh configuration completed successfully.",
        "failure": "❌ Wazuh deployment failed."
    },
    "graylog/install.sh": {
        "start": "� Installing Graylog...",
        "success": "✅ Graylog installation completed successfully.",
        "failure": "❌ Graylog installation failed."
    },
    "graylog/config.sh": {
        "start": "� Configuring Graylog...",
        "success": "✅ Graylog configuration completed successfully.",
        "failure": "❌ Graylog deployment failed."
    },
    "misp/install.sh": {
        "start": "� Cloning and configuring MISP...",
        "success": "✅ MISP cloning and configuration completed successfully.",
        "failure": "❌ MISP cloning and configuration failed."
    },
    "Shuffle-docker/install.sh": {
        "start": "� Cloning and configuring Shuffle...",
        "success": "✅ Shuffle cloning and configuration completed successfully.",
        "failure": "❌ Shuffle cloning and configuration failed."
    },
     "dfir-iris/install.sh": {
        "start": "� Cloning and configuring iris-web...",
        "success": "✅ iris-web cloning and configuration completed successfully.",
        "failure": "❌ iris-web cloning and configuration failed."
    },

    "misp build": {
        "start": "� Building Docker images for MISP...",
        "success": "✅ Docker image build for MISP completed successfully.",
        "failure": "❌ Docker image build for MISP failed."
    },
    "misp up": {
        "start": "� Starting Docker containers for MISP...",
        "success": "✅ Docker containers for MISP started successfully.",
        "failure": "❌ Starting Docker containers for MISP failed."
    },
    "shuffle up": {
        "start": "� Starting Docker containers for Shuffle...",
        "success": "✅ Docker containers for Shuffle started successfully.",
        "failure": "❌ Starting Docker containers for Shuffle failed."
    },
    "dfir-iris pull": {
        "start": "📥 Downloading Docker images for DFIR-IRIS...",
        "success": "✅ Docker images for DFIR-IRIS downloaded successfully.",
        "failure": "❌ Docker images for DFIR-IRIS download failed."
    },
    "dfir-iris up": {
        "start": "� Starting Docker containers for DFIR-IRIS...",
        "success": "✅ Docker containers for DFIR-IRIS started successfully.",
        "failure": "❌ Starting Docker containers for DFIR-IRIS failed."
    },
}

