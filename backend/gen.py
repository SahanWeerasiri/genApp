from seleniumbase import Driver
import time
import traceback
import base64
from styles import styles
class Gen:
    def __init__(self):
        self.driver = None
        url = "https://perchance.org/unrestricted-ai-image-generator"
        try:
            # make this headless
            self.driver = Driver(uc=True, headless=True)

            self.driver.uc_open_with_reconnect('https://perchance.org', 1)
            print("Perchance page opened")

            time.sleep(2)  # Wait for the page to load

            self.driver.execute_script("window.localStorage.setItem('acceptedContentWarningForPage:/unrestricted-ai-image-generator', '1');")
            self.driver.execute_script("window.localStorage.setItem('sensitiveContentVisibility', 'warn');")
            self.driver.execute_script("window.localStorage.setItem('loglevel', 'WARN');")

            print("LocalStorage set")

            self.driver.uc_open_with_reconnect('https://image-generation.perchance.org', 1)
            print("Image generation page opened")

            time.sleep(2)  # Wait for the page to load

            self.driver.execute_script("window.localStorage.setItem('okayToShowNsfwUntil', '2066299973569');")
            print("LocalStorage set for image generation page")

            self.driver.uc_open_with_reconnect(url, 1)
            print("Page opened")

            time.sleep(5)  # Wait for the page to load

            self.driver.switch_to.frame(self.driver.find_element("xpath", "/html/body/div[3]/div[3]/div[1]/div[2]/div[1]/div[1]/iframe"))
            print("Switched to iframe")

            time.sleep(1)  # Wait for the iframe to load

            self.generation("girl")

            img = self.extract_images(count = 6)
            if img:
                print("Image extracted successfully")
                with open("output_image.png", "wb") as fh:
                    fh.write(base64.b64decode(img))
                print("Image saved as output_image.png")
            else:
                print("No image found")    
            print("Initialization complete")
        except:
            traceback.print_exc()
    def extract_images(self, count=6):
        is_success = False
        base64_data = None
        while not is_success:
            for i in range(count):
                try:
                    self.driver.switch_to.frame(self.driver.find_element("xpath", f"/html/body/div[1]/div[4]/div[{i+1}]/iframe"))
                    print("Switched to iframe")
                    img_element = self.driver.find_element("xpath", "/html/body/div[1]/main/div[2]/img")
                    img_url = img_element.get_attribute("src")
                    
                    if img_url.startswith("data:image/jpeg;base64,") or img_url.startswith("data:image/png;base64,") or img_url.startswith("data:image/jpg;base64,"):
                        base64_data = img_url.split(",")[1]
                        is_success = True
                        break
                    else:
                        print("Image URL is not in base64 format")
                except Exception as e:
                    print(f"Error extracting image {i+1}")
                self.driver.switch_to.default_content()  # Switch back to the main content
                print("Switched back to main content")
                self.driver.switch_to.frame(self.driver.find_element("xpath", "/html/body/div[3]/div[3]/div[1]/div[2]/div[1]/div[1]/iframe"))
                print("Switched to iframe")
            self.driver.switch_to.default_content()  # Switch back to the main content
            print("Switched back to main content")
            self.driver.switch_to.frame(self.driver.find_element("xpath", "/html/body/div[3]/div[3]/div[1]/div[2]/div[1]/div[1]/iframe"))
            print("Switched to iframe")
        return base64_data

    def generation(self, prompt, style="default"):
        self.driver.find_element("xpath", "/html/body/div[1]/div[1]/div[2]/div/div[2]/div[1]/textarea").clear()
        self.driver.find_element("xpath", "/html/body/div[1]/div[1]/div[2]/div/div[2]/div[1]/textarea").send_keys(prompt)  # Enter a test prompt
        print("Prompt entered")

        self.driver.find_element("xpath", "/html/body/div[1]/div[3]/div[1]/button").click()  # Click the "Generate" button inside the iframe
        print("Generate button clicked")
        time.sleep(15)
    
    def set_style(self, style="default"):
        # show style list with numbers        
        if style == "default":
            style_choice = input("Enter the number of the style you want to use (default is 1): ").strip()
            if not style_choice:
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
        print(f"Style selected: {styles[int(style_choice) - 1]}")
        time.sleep(1)  # Wait for the style to be applied

    def play(self, prompt:str, style:str = "default"):
        if prompt.strip() == "":
            prompt = "girl"
        self.set_style(style)  # Set default style
        self.generation(prompt)  
        return self.extract_images(count = 6)      
