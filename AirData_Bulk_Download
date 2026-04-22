(async () => {
    const delay = ms => new Promise(res => setTimeout(res, ms));

    const extractIds = () => {
        return [...document.querySelectorAll('input.chk_bulk[name="chk_hash"]')]
            .map(el => el.value.trim())
            .filter(Boolean);
    };

    const waitForTableChange = async (oldHtml) => {
        for (let i = 0; i < 50; i++) { // up to ~5 seconds
            const newHtml = document.querySelector("table tbody").innerHTML;
            if (newHtml !== oldHtml) return;
            await delay(100);
        }
    };

    const nextButton = () =>
        document.querySelector(".paginate_button.next:not(.disabled)");

    let allIds = new Set();

    console.log("Scraping page 1...");
    extractIds().forEach(id => allIds.add(id));

    while (true) {
        const btn = nextButton();
        if (!btn) break; // no more pages

        const oldHtml = document.querySelector("table tbody").innerHTML;

        btn.click();
        await waitForTableChange(oldHtml);
        await delay(200);

        console.log("Scraping next page...");
        extractIds().forEach(id => allIds.add(id));
    }

    const output = [...allIds]
        .map(id => `https://app.airdata.com/original?flight=${id}`)
        .join("\n");

    const ta = document.createElement("textarea");
    ta.value = output;
    ta.style.position = "fixed";
    ta.style.top = "20px";
    ta.style.left = "20px";
    ta.style.width = "600px";
    ta.style.height = "300px";
    ta.style.zIndex = 999999;
    document.body.appendChild(ta);
    ta.select();

    console.log("Done. Copy from the textarea.");
})();
