import asyncio 
from notificationapi_python_server_sdk import notificationapi

async def send_notification():
    notificationapi.init(
        "nysaalf6rdm6jyg8pla5si4cju",  # clientId
        "xvsjcir9jktvmud6vtlpxnon8j217eh3uufighc0gcjlaw8uh9rdw815i9" # clientSecret
    )

    await notificationapi.send({
        "notificationId": "test",
        "user": {
          "id": "aap48@njit.edu",
          "email": "aap48@njit.edu",
          "number": "+16098658865" # Replace with your phone number, use format [+][country code][area code][local number]
        },
        "mergeTags": {
          "comment": "Dana, do you see this?",
          "commentId": "testCommentId"
        }
    })

asyncio.run(send_notification())
