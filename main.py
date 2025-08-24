import requests
import json

BOT_TOKEN = "DEIN_BOT_TOKEN"
GUILD_ID = "DEINE_GUILD_ID"

def print_channels_json():
    url = f"https://discord.com/api/v10/guilds/{GUILD_ID}/channels"
    headers = {"Authorization": f"Bot {BOT_TOKEN}"}
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        print(response.text)  # Das ist das JSON-Array mit allen Channels
    else:
        print(f"Fehler beim Abrufen der Channels: {response.status_code} - {response.text}")

if __name__ == "__main__":
    print_channels_json()


test = {
  "color": {
    "mode": "dynamic",
    "isDark": true,
    "isTinted": true,
    "accentColor": "#6200ee"
  },
  "bg": {
    "mode": "animated",
    "options": {
      "filter": {
        "blur": 32,
        "saturation": 150,
        "contrast": 100,
        "brightness": 40,
        "opacity": 100
      },
      "color": "#060606",
      "imageMode": "player",
      "imageSrc": "https://picsum.photos/1920/1080",
      "autoStopAnimation": true
    }
  },
  "bodyClass": {
    "hideHomeHeader": true,
    "newHome": true,
    "flexyHome": true
  },
  "umv": {
    "type": "default",
    "isScrolling": true,
    "isScaling": true,
    "filter": {
      "blur": 16,
      "saturation": 150,
      "contrast": 100,
      "brightness": 80,
      "opacity": 80
    },
    "customColor": "#060606",
    "customUrl": "https://picsum.photos/1920/1080"
  },
  "uiPreferences": {
    "windowControlHeight": 67,
    "bodyFont": {
      "family": "Inter",
      "variants": [
        "100",
        "200",
        "300",
        "regular",
        "500",
        "600",
        "700",
        "800",
        "900"
      ]
    },
    "titleFont": {
      "family": "Inter",
      "variants": [
        "100",
        "200",
        "300",
        "regular",
        "500",
        "600",
        "700",
        "800",
        "900"
      ]
    },
    "border": {
      "color": "rgba(255,255,255,.1)",
      "hoverColor": "rgba(255,255,255,.2)",
      "thickness": 1,
      "style": "solid"
    }
  },
  "page": {
    "mode": "card",
    "coverMode": "default",
    "homeCardGap": 8,
    "panelGap": 8
  },
  "player": {
    "mode": "normal",
    "autoHide": false,
    "isFloating": true,
    "hideExtraIcon": true,
    "defaultStyle": {
      "height": 80,
      "borderRadius": 8,
      "coverArtRadius": 8,
      "bgOpacity": 50,
      "paddingX": 8,
      "backdropFilter": {
        "blur": 32,
        "saturation": 150,
        "brightness": 50,
        "contrast": 100,
        "opacity": 100
      },
      "bgColor": "var(--main-bg)"
    },
    "compactStyle": {
      "height": 64,
      "borderRadius": 8,
      "coverArtRadius": 8,
      "bgOpacity": 50,
      "paddingX": 8,
      "backdropFilter": {
        "blur": 32,
        "saturation": 150,
        "brightness": 50,
        "contrast": 100,
        "opacity": 100
      },
      "bgColor": "var(--main-bg)"
    }
  },
  "settingModal": {
    "accessPoint": "nav",
    "isFloating": false,
    "floatingPosition": {
      "x": 8,
      "y": 8
    }
  },
  "library": {
    "autoHide": false,
    "hoverTargetWidth": 40,
    "floating": false
  },
  "rightSidebar": {
    "mode": "default",
    "positionX": "right",
    "positionY": "bottom",
    "autoHide": false,
    "hoverTargetWidth": 40,
    "floating": false
  },
  "globalNav": {
    "floating": false,
    "autoHide": false,
    "hoverTargetWidth": 40
  }
}