from locust import HttpLocust, TaskSet

#def login(l):
#    l.client.post("/login", {"username":"ellen_key", "password":"education"})

def index(l):
    l.client.get("/")

def albums(l):
    l.client.get("/albums")

class UserBehavior(TaskSet):
    tasks = {index:2, albums:1}

#    def on_start(self):
#        login(self)

class WebsiteUser(HttpLocust):
    task_set = UserBehavior
    min_wait=5000
    max_wait=9000
