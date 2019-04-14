from flask import Flask
from flask_restful import Resource, Api

import os
from time import sleep

app = Flask(__name__)
api = Api(app)

class HelloWorld(Resource):
    def get(self):
        return {'hello': 'world !'}

class Sleep(Resource):
    def get(self, delay): # delay in milliseconds
        sleep(delay / 1000)
        return {'message': f"Slept for {delay} milliseconds"}

api.add_resource(HelloWorld, '/hello', '/')
api.add_resource(Sleep, '/sleep/<int:delay>')

'''
if __name__ == '__main__':
    debug = os.environ.get('DEBUG') in ['yes', 'true', '1'] 
    app.run(debug=debug)
'''