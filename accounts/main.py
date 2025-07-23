# accounts/main.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/accounts")
@app.get("/accounts/")
def read_accounts():
    return {"message": "This is the accounts service"}
