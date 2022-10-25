# 导入Flask类
from flask import Flask, request, Response
import json
from compute_proof import get_proof_from_whitelist

# 使用当前模块的名称构建Flask app
app = Flask(__name__)

def formatReturnJson(data):
    res = {
        'code': 0,
        'data': data
    }
    return json.dumps(res)

# 获取分类列表
@app.route('/api/proof/getproof', methods = ["POST"])
def getproof():
    data = json.loads(request.data) 
    proof = get_proof_from_whitelist(int(bytes(data["address"], 'utf-8').hex(), 16))
    sData = []
    for item in proof:
        sData.append(hex(item))
    res_data = formatReturnJson(sData)
    return Response(res_data, mimetype="application/json;utf-8")

# 运行程序
if __name__ == '__main__':
    app.run()
