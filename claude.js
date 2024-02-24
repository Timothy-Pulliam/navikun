// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import { fileURLToPath } from "url";
import dotenv from "dotenv";

dotenv.config()

import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";

/**
 * @typedef {Object} ResponseBody
 * @property {string} completion
 */

/**
 * Invokes the Anthropic Claude 2 model to run an inference using the input
 * provided in the request body.
 *
 * @param {string} prompt - The prompt that you want Claude to complete.
 * @returns {string} The inference response (completion) from the model.
 */
export const invokeClaude = async (prompt) => {
    const client = new BedrockRuntimeClient({ region: process.env.AWS_REGION });

    const modelId = process.env.AWS_BEDROCK_MODEL_ID;

    /* Claude requires you to enclose the prompt as follows: */
    const enclosedPrompt = `Human: ${prompt}\n\nAssistant:`;

    /* The different model providers have individual request and response formats.
     * For the format, ranges, and default values for Anthropic Claude, refer to:
     * https://docs.aws.amazon.com/bedrock/latest/userguide/model-parameters-claude.html
     */
    const payload = {
        prompt: enclosedPrompt,
        max_tokens_to_sample: 200,
        temperature: 0.5,
        stop_sequences: ['\n\nHuman:'],
    };

    const command = new InvokeModelCommand({
        body: JSON.stringify(payload),
        contentType: 'application/json',
        accept: 'application/json',
        modelId,
    });

    try {
        const response = await client.send(command);
        const decodedResponseBody = new TextDecoder().decode(response.body);

        /** @type {ResponseBody} */
        const responseBody = JSON.parse(decodedResponseBody);

        return responseBody.completion;

    } catch (err) {
        console.error(err);
    }
};

// Invoke the function if this file was run directly.
// if (process.argv[1] === fileURLToPath(import.meta.url)) {
//     const prompt = 'Complete the following: "Once upon a time..."';
//     console.log('\nModel: Anthropic Claude v2');
//     console.log(`Prompt: ${prompt}`);

//     const completion = await invokeClaude(prompt);
//     console.log('Completion:');
//     console.log(completion);
//     console.log('\n');
// }

