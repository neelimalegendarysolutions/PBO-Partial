({
    doInit: function (component, event, helper) {
        var flow = component.find("flowData");
        flow.startFlow(component.get("v.flowName"));
    },

    handleStatusChange: function (component, event, helper) {
        var status = event.getParam("status");

        if (status === "FINISHED" || status === "FINISHED_SCREEN") {
            var outputVariables = event.getParam("outputVariables") || [];
            var projectId;

            outputVariables.forEach(function (ov) {
                if (ov.name === "ProjectId" || ov.name === "recordId") {
                    projectId = ov.value;
                }
            });

            if (projectId) {
                var navEvt = $A.get("e.force:navigateToSObject");
                if (navEvt) {
                    navEvt.setParams({ recordId: projectId });
                    navEvt.fire();
                    return;
                }
            }

            var listViewEvt = $A.get("e.force:navigateToObjectHome");
            if (listViewEvt) {
                listViewEvt.setParams({ scope: "Jpeto__Project__c" });
                listViewEvt.fire();
            } else if (window.history && window.history.length > 1) {
                window.history.back();
            } else {
                window.location.href = '/s/';
            }
        }
    },

    handleClose: function (component, event, helper) {
        // 🧭 Try to go back first
        if (window.history && window.history.length > 1) {
            window.history.back();
        } else {
            // 🚪 Fallback: Go to home page or list view
            var listViewEvt = $A.get("e.force:navigateToObjectHome");
            if (listViewEvt) {
                listViewEvt.setParams({ scope: "Jpeto__Project__c" });
                listViewEvt.fire();
            } else {
                window.location.href = '/s/';
            }
        }
    }
});