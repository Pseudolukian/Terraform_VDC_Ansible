import json,hcl

'''
with open ("terraform.tfstate","r") as state:
    out = json.load(state)

for item in out["resources"]:
    for k,v in item.items():
        if v == "vcd_nsxv_dnat":
           for it in item["instances"]:
               for k2,v2 in it.items():
                    if k2 == "attributes":
                        print(v2["original_port"],v2["translated_address"])
'''

with open("variables.tf", "r") as fp:
    obj = hcl.load(fp)

print(obj)