import requests

def get_head(url):
    try:
        response = requests.get(url, timeout=5)
        
        response.raise_for_status()
        
        print(f"Headers for {url}:")
        for key, value in response.headers.items():
            print(f"  {key}: {value}")
            
    except requests.exceptions.RequestException as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    website_url = "http://www.elg.no"
    get_head(website_url)