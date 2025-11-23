from dotenv import load_dotenv
import os

load_dotenv()


from backend.src.agent.agent import main
from backend.src.agent.supervisor import test

if __name__ == "__main__":
    #main()
    test()

