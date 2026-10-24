from firebase_functions import https_fn
from firebase_admin import initialize_app, firestore
import google.generativeai as genai
import requests
import os
import re
import json
from config import GEMINI_API_KEY  # Import your local config key

initialize_app()

@https_fn.on_callable()
def process_transaction(req: https_fn.CallableRequest) -> dict:
    text = req.data.get("text")
    uid = req.auth.uid if req.auth else None

    if not uid:
        return {"error": "Unauthorized user."}
    if not text:
        return {"error": "No text provided."}

    try:
        # 1. Call Gemini to parse transaction data
        genai.configure(api_key=GEMINI_API_KEY) # Use the imported key
        model = genai.GenerativeModel("models/gemini-2.5-flash")
        
        prompt = f"""
        Extract data from: "{text}"
        Return ONLY a valid JSON object. Do not include any markdown formatting or preamble.
        Required Keys:
        "amount": (number),
        "currency": (3-letter ISO code, e.g. USD, EUR. default to "USD" if unclear),
        "type": ("income" or "expense"),
        "category": (string),
        "description": (string)
        """
        
        response = model.generate_content(prompt)
        response_text = response.text
        
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            clean_json = json_match.group(0)
        else:
            clean_json = response_text.replace("```json", "").replace("```", "").strip()

        data = json.loads(clean_json)

        # 2. Handle Currency Conversion server-side
        original_amount = float(data.get("amount", 0))
        currency = data.get("currency", "USD").upper()
        usd_value = original_amount

        if currency != "USD":
            try:
                url = f"https://api.frankfurter.app/latest?amount={original_amount}&from={currency}&to=USD"
                res = requests.get(url)
                if res.status_code == 200:
                    usd_value = float(res.json()["rates"]["USD"])
            except Exception as e:
                print(f"Currency conversion error: {e}")

        data["amount_usd"] = round(usd_value, 2)
        data["timestamp"] = firestore.SERVER_TIMESTAMP

        # 3. Save to Firestore securely from the server
        db = firestore.client()
        db.collection("users").doc(uid).collection("transactions").add(data)

        return {"success": True, "data": data}

    except Exception as e:
        return {"error": str(e)}