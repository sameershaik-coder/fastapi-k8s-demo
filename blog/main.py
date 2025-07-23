# blog/main.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/blog/")
def read_blog():
    return {"message": "This is the blog service"}
