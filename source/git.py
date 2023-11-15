import os
import time
import pygit2

def gitRepair(repo, origin):
    repo.remotes.delete("origin")
    repo.create_remote("origin", origin)
    repo.remotes["origin"].fetch()

def gitReset(path, origin):
    repo = pygit2.Repository(os.path.abspath(path))
    repo.remotes.set_url("origin", origin)
    repo.remotes["origin"].fetch()
    try:
        head = repo.lookup_reference("refs/remotes/origin/master").raw_target
    except:
        gitRepair(repo, origin)
        head = repo.lookup_reference("refs/remotes/origin/master").raw_target
    repo.reset(head, pygit2.GIT_RESET_HARD)

def gitLast(path):
    try:
        repo = pygit2.Repository(os.path.abspath(path))
        commit = repo[repo.head.target]
        message = commit.raw_message.decode('utf-8').strip()
        delta = time.time() - commit.commit_time
    except:
        return None, None
    
    spans = [
        ('year', 60*60*24*365),
        ('month', 60*60*24*30),
        ('day', 60*60*24),
        ('hour', 60*60),
        ('minute', 60),
        ('second', 1)
    ]
    when = "?"
    for label, span in spans:
        if delta >= span:
            count = int(delta//span)
            suffix = "" if count == 1 else "s"
            when = f"{count} {label}{suffix} ago"
            break

    return commit, f"{message} ({commit.short_id}) ({when})"

def gitInit(path, origin):
    repo = pygit2.init_repository(os.path.abspath(path), False)
    if not "origin" in repo.remotes:
        repo.create_remote("origin", origin)
    gitReset(path, origin)

def gitClone(path, origin):
    pygit2.clone_repository(origin, path)