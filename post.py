import requests

def get_postal(url, headers, data):
    try:
        response = requests.post(url, headers=headers, json=data, timeout=5)
        response.raise_for_status()

        print(f"POST to {url} achieved! Status: {response.status_code}")
        print("\nTried to post:")
        for key, value in headers.items():
            print(f"  {key}: {value}")

        print("\nResponse:")
        print(response.json())

    except requests.exceptions.RequestException as e:
        print(f"Failure: {e}")

    except ValueError:
        print("Not JSON.")

    except Exception as e:
        print(f"Something failed spectacularly: {e}")

if __name__ == "__main__":
    post_url = "https://httpbin.org/post"
    custom_headers = {
        'User-Agent': 'Secret Agent Man/1.0',
        'Accept-Language': 'en-US,en;q=0.9',
        'Custom-Header-Name': 'Bond, James Bond'
    }

    payload_data = {
        "name": "James Bond",
        "age": 42,
        "location": "MI5 Headquarters"
    }

    get_postal(post_url, custom_headers, payload_data)