import json

def lambda_handler(event, context):
    status_code = event.get("statusCode", "")
    
    
    if (status_code == 200):
        
        food_insight = {} # Some object created from food_info and user data in dynamo db ;)
        
        currated_user_results = {
            "food_info" : json.loads(event.get("body", {}))["food_info"],
            "food_insight" : food_insight
        }
        
        return {
                "statusCode": 200,
                "body": json.dumps({"currated_user_results": currated_user_results})
            }
        
    return {}