import app.fleet_workflow as fw

g = fw.FLEET_WORKFLOW.graph
assert g is not None, "FLEET_WORKFLOW graph must be constructed"
S = g.get_next_pending_nodes


def show(n, r):
    print(f"{n} route={r!r:16} -> {S(n, r)}")


show("arch_review_gate_node", "revise_arch")
show("arch_review_gate_node", None)
show("code_review_node", "rework_code")
show("code_review_node", None)
show("code_review_gate_node", "rework_code")
show("code_review_gate_node", None)
show("compliance_gate_node", "rework_compliance")
show("compliance_gate_node", None)
show("compliance_gate_node", "rework_compliance")

print()
print("EXPECTED:")
print("  arch_rev revise_arch -> [architect_node]")
print("  arch_rev default     -> [leaddev_node]")
print("  code_rev rework_code -> [leaddev_node]")
print("  code_rev default     -> [code_review_gate_node]")
print("  code_rev_g rework    -> [leaddev_node]")
print("  code_rev_g default   -> [compliance_node]")
print("  comp_g rework_compl  -> [leaddev_node]")
print("  comp_g default       -> [marketing_node]")