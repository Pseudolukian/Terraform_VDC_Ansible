import json

from pprint import pprint


with open ("terraform.tfstate","r") as state:
    out = json.load(state)["resources"]

for k in out:
    pprint(k["type"])

