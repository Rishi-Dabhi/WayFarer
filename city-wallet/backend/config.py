from pydantic_settings import BaseSettings
from typing import Any


class Settings(BaseSettings):
    anthropic_api_key: str = ""
    openweather_api_key: str = ""
    eventbrite_token: str = ""
    mapbox_token: str = ""
    gemma_base_url: str = "http://localhost:11434"
    gemma_model: str = "gemma3:1b"
    gemma_enabled: bool = True
    stripe_secret_key: str = ""
    stripe_publishable_key: str = ""
    stripe_webhook_secret: str = ""
    jwt_secret: str = "dev-secret-change-me"
    database_url: str = "./city_wallet.db"
    mongodb_url: str = ""
    seed_demo_data: bool = False

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()

# Demo context overrides — activated with ?demo=<key> on the generate endpoint
DEMO_CONTEXTS: dict[str, dict[str, Any]] = {
    "rainy_quiet": {
        "weather": {"temp": 8, "feels_like": 5, "condition": "light rain", "icon": "10d"},
        "busyness_override": "quiet",
        "payone_txn_override": 2,
        "events": [],
    },
    "sunny_lunch_busy": {
        "weather": {"temp": 22, "feels_like": 21, "condition": "clear sky", "icon": "01d"},
        "busyness_override": "normal",
        "payone_txn_override": 14,
        "events": [{"name": "Stuttgart Market", "distance_m": 350}],
    },
    "evening_event": {
        "weather": {"temp": 15, "feels_like": 13, "condition": "few clouds", "icon": "02n"},
        "busyness_override": "quiet",
        "payone_txn_override": 5,
        "events": [
            {"name": "Jazz Night at Staatstheater", "distance_m": 180},
            {"name": "Street Food Festival", "distance_m": 420},
        ],
    },
}
