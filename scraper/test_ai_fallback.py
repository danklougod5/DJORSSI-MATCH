
import os
import sys
from dotenv import load_dotenv

# Add src to path
sys.path.append(os.path.join(os.getcwd(), "src"))

from core.ai_validator import AIJobValidator

def test_validator():
    validator = AIJobValidator()
    
    raw_text = """
    OFFRE D'EMPLOI: Développeur Python Junior
    Entreprise: Djossi Tech
    Lieu: Abidjan, Côte d'Ivoire
    Type: CDD
    Email de contact: hr@djossi.ci
    Description: Nous recherchons un développeur passionné par Python.
    """
    
    print("\n--- Testing Validation ---")
    result = validator.validate_and_clean_job(raw_text)
    
    if result:
        print("Success!")
        print(result)
    else:
        print("Failed to get result from AI.")

if __name__ == "__main__":
    test_validator()
