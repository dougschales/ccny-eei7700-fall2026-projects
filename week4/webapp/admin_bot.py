#!/usr/bin/env python3
"""
Simulated administrator: logs into the portal with real credentials and
periodically reviews the /comments page in a real headless browser. Any
JavaScript stored in a comment (stored XSS) runs in this "admin" browser
session, which is how the FLAG3 cookie gets stolen by an attacker.

Note for students: the Flask session cookie is HttpOnly (can't be read by
JS - notice you can't steal it with document.cookie). The separate
'session_token' cookie set below is intentionally NOT HttpOnly, simulating
a legacy/poorly-configured secondary token. That's the one you want.
"""
import os
import time

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

APP_URL = "http://127.0.0.1:80"
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "K3ep_This_S3cr3t_9f2a")
FLAG3 = "flag{w4_3_st0r3d_xss_c00k13_th3ft}"
POLL_INTERVAL = 15


def build_driver():
    opts = Options()
    opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--disable-gpu")
    opts.binary_location = "/usr/bin/chromium"
    return webdriver.Chrome(options=opts)


def admin_login(driver):
    driver.get(f"{APP_URL}/login")
    driver.find_element(By.NAME, "username").send_keys("admin")
    driver.find_element(By.NAME, "password").send_keys(ADMIN_PASSWORD)
    driver.find_element(By.CSS_SELECTOR, "input[type=submit]").click()
    time.sleep(1)
    # Legacy secondary session token, deliberately not HttpOnly.
    driver.add_cookie({
        "name": "session_token",
        "value": FLAG3,
        "path": "/",
        "httpOnly": False,
    })


def main():
    print("[admin_bot] starting headless browser...", flush=True)
    driver = build_driver()
    try:
        while True:
            try:
                admin_login(driver)
                driver.get(f"{APP_URL}/comments")
                time.sleep(3)  # give injected JS time to execute
                print("[admin_bot] reviewed /comments as admin", flush=True)
            except Exception as e:
                print(f"[admin_bot] error: {e}", flush=True)
            time.sleep(POLL_INTERVAL)
    finally:
        driver.quit()


if __name__ == "__main__":
    main()
