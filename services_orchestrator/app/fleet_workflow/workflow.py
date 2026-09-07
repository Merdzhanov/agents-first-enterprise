    edges=[
        ("START", scout_node, planner_gate_node, repo_decision_gate_node, architect_node, arch_review_gate_node),
        # Repo decision gate: use existing ↪ architect | create new ↪ repo_decision (re-provision)
        (
            repo_decision_gate_node,
            {
                "create_new_repo": repo_decision_gate_node,
                "__DEFAULT__": architect_node,
            },
        ),