from seleniumbase import Driver
import time
import traceback
import base64
import os
import requests
import io
from styles import styles

class Gen:
    def __init__(self, worker_id=None):
        # Use worker_id to create separate directories and profiles
        if worker_id is None:
            worker_id = os.getenv('WORKER_ID', 'default')
        
        self.worker_id = worker_id
        
        # Telegram bot configuration
        self.SECOND_BOT_TOKEN = os.getenv('SECOND_BOT_TOKEN')
        self.SECOND_BOT_CHAT_ID = "1668869874"  # Fixed chat ID for the second bot
        
        # Create worker-specific directories
        base_dir = os.path.dirname(os.path.abspath(__file__))
        self.worker_dir = os.path.join(base_dir, f"worker_data_{worker_id}")
        self.downloaded_files = os.path.join(self.worker_dir, "downloaded_files")
        
        # Create directories if they don't exist
        os.makedirs(self.downloaded_files, exist_ok=True)
        
        print(f"Worker {worker_id}: Using directories:")
        print(f"  - Downloads: {self.downloaded_files}")
        
        self.driver = None
        url = "https://perchance.org/unrestricted-ai-image-generator"
        try:
            # Set up driver without chrome profile
            self.driver = Driver(
                uc=True, 
                headless=True
            )

            self.driver.uc_open_with_reconnect('https://perchance.org', 1)
            print(f"Worker {self.worker_id}: Perchance page opened")

            time.sleep(2)  # Wait for the page to load

            self.driver.execute_script("window.localStorage.setItem('acceptedContentWarningForPage:/unrestricted-ai-image-generator', '1');")
            self.driver.execute_script("window.localStorage.setItem('sensitiveContentVisibility', 'warn');")
            self.driver.execute_script("window.localStorage.setItem('loglevel', 'WARN');")

            print(f"Worker {self.worker_id}: LocalStorage set")

            self.driver.uc_open_with_reconnect('https://image-generation.perchance.org', 1)
            print(f"Worker {self.worker_id}: Image generation page opened")

            time.sleep(2)  # Wait for the page to load

            self.driver.execute_script("window.localStorage.setItem('okayToShowNsfwUntil', '2066299973569');")
            print(f"Worker {self.worker_id}: LocalStorage set for image generation page")

            self.driver.uc_open_with_reconnect(url, 1)
            print(f"Worker {self.worker_id}: Page opened")

            time.sleep(5)  # Wait for the page to load

            self.driver.switch_to.frame(self.driver.find_element("xpath", "/html/body/div[3]/div[3]/div[1]/div[2]/div[1]/div[1]/iframe"))
            print(f"Worker {self.worker_id}: Switched to iframe")

            time.sleep(1)  # Wait for the iframe to load

            self.generation("girl")

            img = self.extract_images(count = 6)
            if img:
                print(f"Worker {self.worker_id}: Image extracted successfully")
                # Save to worker-specific directory
                image_path = os.path.join(self.downloaded_files, "output_image.png")
                with open(image_path, "wb") as fh:
                    fh.write(base64.b64decode(img))
                print(f"Worker {self.worker_id}: Image saved as {image_path}")
                
                # Send initialization image to Telegram
                self.send_image_to_telegram_bot(img, "girl", "initialization")
            else:
                print(f"Worker {self.worker_id}: No image found")    
            print(f"Worker {self.worker_id}: Initialization complete")
        except:
            traceback.print_exc()
    
    def send_image_to_telegram_bot(self, image_b64, prompt, style="initialization"):
        """Send generated image to the Telegram bot"""
        if not self.SECOND_BOT_TOKEN:
            print(f"Worker {self.worker_id}: SECOND_BOT_TOKEN not found in environment variables")
            return False
        
        try:
            # Convert base64 to bytes
            image_bytes = base64.b64decode(image_b64)
            
            # Prepare the file for Telegram API
            files = {
                'photo': ('generated_image.png', io.BytesIO(image_bytes), 'image/png')
            }
            
            data = {
                'chat_id': self.SECOND_BOT_CHAT_ID,
                'caption': f"🤖 {style.title()} Image Generated! 🤖\nPrompt: {prompt}\nWorker: {self.worker_id}\nTime: {time.strftime('%Y-%m-%d %H:%M:%S')}"
            }
            
            # Send photo to Telegram bot
            url = f"https://api.telegram.org/bot{self.SECOND_BOT_TOKEN}/sendPhoto"
            response = requests.post(url, files=files, data=data, timeout=30)
            
            if response.status_code == 200:
                print(f"Worker {self.worker_id}: {style.title()} image sent successfully to Telegram bot")
                return True
            else:
                print(f"Worker {self.worker_id}: Failed to send {style} image to Telegram bot: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"Worker {self.worker_id}: Error sending {style} image to Telegram bot: {e}")
            return False

    def extract_images(self, count=6):
        is_success = False
        base64_data = None
        while not is_success:
            for i in range(count):
                try:
                    self.driver.switch_to.frame(self.driver.find_element("xpath", f"/html/body/div[1]/div[4]/div[{i+1}]/iframe"))
                    print(f"Worker {self.worker_id}: Switched to iframe")
                    img_element = self.driver.find_element("xpath", "/html/body/div[1]/main/div[2]/img")
                    img_url = img_element.get_attribute("src")
                    
                    if img_url.startswith("data:image/jpeg;base64,") or img_url.startswith("data:image/png;base64,") or img_url.startswith("data:image/jpg;base64,"):
                        base64_data = img_url.split(",")[1]
                        is_success = True
                        break
                    else:
                        print(f"Worker {self.worker_id}: Image URL is not in base64 format")
                except Exception as e:
                    print(f"Worker {self.worker_id}: Error extracting image {i+1}")
                self.driver.switch_to.default_content()  # Switch back to the main content
                print(f"Worker {self.worker_id}: Switched back to main content")
                self.driver.switch_to.frame(self.driver.find_element("xpath", "/html/body/div[3]/div[3]/div[1]/div[2]/div[1]/div[1]/iframe"))
                print(f"Worker {self.worker_id}: Switched to iframe")
            self.driver.switch_to.default_content()  # Switch back to the main content
            print(f"Worker {self.worker_id}: Switched back to main content")
            self.driver.switch_to.frame(self.driver.find_element("xpath", "/html/body/div[3]/div[3]/div[1]/div[2]/div[1]/div[1]/iframe"))
            print(f"Worker {self.worker_id}: Switched to iframe")
        return base64_data

    def generation(self, prompt, style="default"):
        self.driver.find_element("xpath", "/html/body/div[1]/div[1]/div[2]/div/div[2]/div[1]/textarea").clear()
        self.driver.find_element("xpath", "/html/body/div[1]/div[1]/div[2]/div/div[2]/div[1]/textarea").send_keys(prompt)  # Enter a test prompt
        print(f"Worker {self.worker_id}: Prompt entered")

        self.driver.find_element("xpath", "/html/body/div[1]/div[3]/div[1]/button").click()  # Click the "Generate" button inside the iframe
        print(f"Worker {self.worker_id}: Generate button clicked")
        time.sleep(15)
    
    def set_style(self, style="default"):
        # show style list with numbers        
        if style == "default":
            # style_choice = input("Enter the number of the style you want to use (default is 1): ").strip()
            # if not style_choice:
                style_choice = "1"
        else:
            style_choice = styles.index(style) + 1 if style in styles else "1"
        # path /html/body/div[1]/div[1]/div[4]/div/div[2]/select
        style_select = self.driver.find_element("xpath", "/html/body/div[1]/div[1]/div[4]/div/div[2]/select")
        #select a style
        style_select.click()
        time.sleep(1)  # Wait for the dropdown to open
        # option path - /html/body/div[1]/div[1]/div[4]/div/div[2]/select/option[1], /html/body/div[1]/div[1]/div[4]/div/div[2]/select/option[2], ...
        style_option = self.driver.find_element("xpath", f"/html/body/div[1]/div[1]/div[4]/div/div[2]/select/option[{int(style_choice)}]")
        style_option.click()
        print(f"Worker {self.worker_id}: Style selected: {styles[int(style_choice) - 1]}")
        time.sleep(1)  # Wait for the style to be applied

    def play(self, prompt:str, style:str = "default"):
        if prompt.strip() == "":
            prompt = "girl"
        self.set_style(style)  # Set default style
        self.generation(prompt)  
        return self.extract_images(count = 6)      
