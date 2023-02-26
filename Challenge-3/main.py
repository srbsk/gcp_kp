def get_value(obj, key):
    keys = key.split('/')  
    for k in keys:
        obj = obj.get(k)
        if obj is None:
            return None
    return obj

obj1 = {"a":{"b":{"c":"d"}}}
key1 = "a/b/c"
print(get_value(obj1, key1))

obj2 = {"x":{"y":{"z":"a"}}}
key2 = "x/y/z"
print(get_value(obj2, key2))