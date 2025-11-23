// Auto-dismiss flash messages after 3 seconds
export const AutoDismissFlash = {
    mounted() {
        // Auto-dismiss after 3 seconds
        this.timeout = setTimeout(() => {
            // Trigger the click event to dismiss the flash
            this.el.click();
        }, 3000);
    },

    destroyed() {
        // Clean up timeout if component is destroyed before auto-dismiss
        if (this.timeout) {
            clearTimeout(this.timeout);
        }
    }
};

// Initialize auto-dismiss for all flash messages on page load
window.addEventListener("phx:page-loading-stop", () => {
    document.querySelectorAll('[id^="flash-"]').forEach((flash) => {
        if (!flash.dataset.autoDismissed) {
            flash.dataset.autoDismissed = "true";
            setTimeout(() => {
                flash.click();
            }, 3000);
        }
    });
});
