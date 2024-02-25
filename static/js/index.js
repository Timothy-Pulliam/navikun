function getPrompt() {
    const prompt = document.getElementById('prompt').value;
    return prompt;
}

function clearPrompt() {
    document.getElementById('prompt').value = '';
    // return undefined
}

// Submit prompt form on Enter
document
    .getElementById('prompt')
    .addEventListener('keydown', async function (event) {
        if (event.key === "Enter" && !event.shiftKey) {
            event.preventDefault();

            // Append prompt and response to history
            const hr = document.createElement('hr');
            hr.classList.add("w-2/3", "h-px", "my-8", "bg-gray-200", "border-0", "dark:bg-gray-700")
            document.getElementById('prompt-history').appendChild(hr);

            const prompt = getPrompt();
            clearPrompt();

            var element = document.createElement('p');
            element.classList.add("text-xl", "font-bold");
            element.innerText = prompt;
            document.getElementById('prompt-history').appendChild(element);

            var element = document.createElement('br');
            document.getElementById('prompt-history').appendChild(element);

            const response = await invokeClaude(event, prompt);
            console.log(response);
            var element = document.createElement('pre');
            element.classList.add("text-left", "whitespace-pre-wrap");
            element.innerText = response;
            document.getElementById("prompt-history").appendChild(element);

            var element = document.createElement('br');
            document.getElementById('prompt-history').appendChild(element);
        }
    });

// Send Prompt to backend
async function invokeClaude(event, prompt) {
    event.preventDefault(); // this will stop the form reload

    const response = await fetch("/", {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json' // Set the content type to JSON
        },
        body: JSON.stringify({ prompt })
    });

    const responseJson = await response.json();
    return responseJson.response

    /* type(responseJson.response, document.getElementById('response'), 100) */
}


// Typing effect
function type(str, targetElem, speedInMs) {
    let i = 0;

    (function write() {
        targetElem.innerHTML += str[i];
        i++;

        if (i < str.length) {
            setTimeout(write, speedInMs);
        }
    })();
}



// Blinking Cursor Effect
// var cursor = true;
// var speed = 250;
// setInterval(() => {
//     if (cursor) {
//         document
//             .getElementById('cursor')
//             .style
//             .opacity = 0;
//         cursor = false;
//     } else {
//         document
//             .getElementById('cursor')
//             .style
//             .opacity = 1;
//         cursor = true;
//     }
// }, speed);
