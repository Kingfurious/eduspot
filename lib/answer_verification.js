// answer_verification.js (Firebase Cloud Function)
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
// Initialize Firebase if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

exports.verifySubmission = functions.https.onCall(async (data, context) => {
  // Authenticate the user
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { projectId, levelName, submittedCode, submittedOutput, submittedText } = data;
  const submissionType = data.submissionType || 'code'; // Default to code submission
  const userId = context.auth.uid;

  // Get the verification criteria from Firestore
  const answerDoc = await admin.firestore()
    .collection('answers')
    .doc(projectId)
    .collection('levels')
    .doc(levelName)
    .get();

  if (!answerDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Answer criteria not found');
  }

  const answerData = answerDoc.data();
  const expectedOutput = answerData.expectedOutput;
  const expectedOutputs = answerData.expectedOutputs || [];
  const requiredKeywords = answerData.requiredKeywords || [];
  const passingScore = answerData.passingScore || 70.0; // Default passing score

  // First run basic verification checks
  let basicVerificationResult = await performBasicVerification(
    submissionType, submittedCode, submittedOutput, submittedText,
    expectedOutput, expectedOutputs, requiredKeywords
  );

  // If basic verification passes with high confidence, return result immediately
  if (basicVerificationResult.isCorrect && basicVerificationResult.confidence >= 0.9) {
    await saveVerificationResult(userId, projectId, levelName, basicVerificationResult, data);
    return basicVerificationResult;
  }

  // Otherwise, use Gemini API for more advanced verification
  try {
    const verificationResult = await performGeminiVerification(
      submissionType, data, answerData
    );

    // Save the result to Firestore
    await saveVerificationResult(userId, projectId, levelName, verificationResult, data);

    return verificationResult;
  } catch (error) {
    console.error('Error during Gemini verification:', error);

    // Fallback to basic verification if Gemini fails
    await saveVerificationResult(userId, projectId, levelName, basicVerificationResult, data);
    return basicVerificationResult;
  }
});

async function performBasicVerification(
  submissionType, submittedCode, submittedOutput, submittedText,
  expectedOutput, expectedOutputs, requiredKeywords
) {
  // Code submission verification
  if (submissionType === 'code') {
    // Check for required keywords in code
    const keywordCheck = requiredKeywords.length === 0 ||
      requiredKeywords.every(keyword =>
        submittedCode.toLowerCase().includes(keyword.toLowerCase())
      );

    // Calculate keyword score
    let keywordScore = 0;
    let missingKeywords = [];

    if (requiredKeywords.length > 0) {
      let keywordsFound = 0;
      for (const keyword of requiredKeywords) {
        if (submittedCode.toLowerCase().includes(keyword.toLowerCase())) {
          keywordsFound++;
        } else {
          missingKeywords.push(keyword);
        }
      }
      keywordScore = (keywordsFound / requiredKeywords.length) * 30.0;
    } else {
      keywordScore = 30.0; // Full score if no keywords required
    }

    // Check output
    let outputCheck = false;
    if (expectedOutputs.length > 0) {
      const normalizedOutput = normalizeText(submittedOutput);
      outputCheck = expectedOutputs.some(expected =>
        normalizedOutput === normalizeText(expected)
      );
    } else if (expectedOutput) {
      const normalizedOutput = normalizeText(submittedOutput);
      const normalizedExpected = normalizeText(expectedOutput);
      outputCheck = normalizedOutput === normalizedExpected;
    }

    const outputScore = outputCheck ? 40.0 : 0.0;
    const totalScore = keywordScore + outputScore + 30.0; // Assume full conceptual score
    const isCorrect = totalScore >= 70.0;

    return {
      isCorrect,
      totalScore,
      confidence: keywordCheck && outputCheck ? 0.95 : 0.6,
      components: {
        codeStructure: {
          score: keywordScore,
          maxScore: 30.0,
          details: { keywordCheck, missingKeywords }
        },
        output: {
          score: outputScore,
          maxScore: 40.0,
          details: { exactMatch: outputCheck }
        },
        conceptual: {
          score: 30.0,
          maxScore: 30.0
        }
      },
      feedback: {
        codeStructure: keywordCheck ?
          ['All required elements are present in your code'] :
          ['Your code is missing some required elements'],
        output: outputCheck ?
          ['Your output matches the expected result'] :
          ['Your output does not match the expected result'],
        conceptual: ['Good work on the implementation']
      }
    };
  } else {
    // Text submission verification
    const textCheck = requiredKeywords.length === 0 ||
      requiredKeywords.every(keyword =>
        submittedText.toLowerCase().includes(keyword.toLowerCase())
      );

    return {
      isCorrect: textCheck,
      confidence: textCheck ? 0.9 : 0.5,
      feedback: textCheck ?
        ['Your answer contains all the required elements'] :
        ['Your answer is missing some key elements']
    };
  }
}

async function performGeminiVerification(submissionType, data, answerData) {
  const GEMINI_API_KEY = "AIzaSyCebLrwpwyMb7cLkkAT7y1O0B0i4NU4kgY";
  const { projectId, levelName, submittedCode, submittedOutput, submittedText } = data;

  // Extract expected answers from answerData
  const expectedOutput = answerData.expectedOutput || '';
  const expectedOutputs = answerData.expectedOutputs || [];
  const requiredKeywords = answerData.requiredKeywords || [];
  const passingScore = answerData.passingScore || 70.0;
  const projectType = answerData.projectType || '';
  const conceptPatterns = answerData.conceptPatterns || [];

  let prompt = "";

  if (submissionType === 'code') {
    prompt = `
      I need you to evaluate a student's code submission for a programming assignment.

      Project ID: ${projectId}
      Level: ${levelName}
      Project Type: ${projectType}

      EXPECTED OUTPUT:
      ${expectedOutput}

      ALTERNATIVE EXPECTED OUTPUTS:
      ${expectedOutputs.join('\n')}

      REQUIRED KEYWORDS/CONCEPTS:
      ${requiredKeywords.join(', ')}

      STUDENT'S CODE SUBMISSION:
      ${submittedCode}

      STUDENT'S OUTPUT:
      ${submittedOutput}

      Please evaluate this submission based on:
      1. Code Structure (30%): Does it contain all required keywords/patterns?
      2. Output Correctness (40%): Does the output match the expected output?
      3. Conceptual Understanding (30%): Does the implementation show proper understanding?

      Provide your evaluation in the following JSON format:
      {
        "isCorrect": true/false,
        "totalScore": 85.5,
        "components": {
          "codeStructure": {
            "score": 25.0,
            "maxScore": 30.0,
            "details": {
              "keywordCheck": true/false,
              "missingKeywords": ["keyword1", "keyword2"]
            }
          },
          "output": {
            "score": 35.5,
            "maxScore": 40.0,
            "details": {
              "exactMatch": true/false
            }
          },
          "conceptual": {
            "score": 25.0,
            "maxScore": 30.0
          }
        },
        "feedback": {
          "codeStructure": ["Feedback point 1", "Feedback point 2"],
          "output": ["Feedback point 1"],
          "conceptual": ["Feedback point 1", "Feedback point 2"]
        }
      }

      A submission is considered correct if totalScore >= ${passingScore}.
      Be fair but rigorous in your assessment.
    `;
  } else {
    prompt = `
      I need you to evaluate a student's text response for an assignment.

      Project ID: ${projectId}
      Level: ${levelName}

      REQUIRED CONCEPTS/KEYWORDS:
      ${requiredKeywords.join(', ')}

      STUDENT'S ANSWER:
      ${submittedText}

      Please evaluate if this text submission contains all the required concepts/keywords.
      Consider synonyms and alternative phrasings.

      Provide your evaluation in the following JSON format:
      {
        "isCorrect": true/false,
        "totalScore": 85.0,
        "components": {
          "contentCompleteness": {
            "score": 42.5,
            "maxScore": 50.0
          },
          "conceptualUnderstanding": {
            "score": 42.5,
            "maxScore": 50.0
          }
        },
        "feedback": ["Feedback point 1", "Feedback point 2"]
      }

      A submission is considered correct if totalScore >= ${passingScore}.
    `;
  }

  try {
    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=${GEMINI_API_KEY}`,
      {
        contents: [{
          parts: [{ text: prompt }]
        }],
        generationConfig: {
          temperature: 0.2,
          topK: 1,
          topP: 0.8,
          maxOutputTokens: 8192,
        }
      }
    );

    // Extract the JSON response
    const text = response.data.candidates[0].content.parts[0].text;
    const jsonPattern = /\{\s*"isCorrect".*\}/s;
    const match = text.match(jsonPattern);

    if (match) {
      const jsonStr = match[0];
      const result = JSON.parse(jsonStr);
      return result;
    } else {
      throw new Error("Couldn't parse verification result from Gemini response");
    }
  } catch (error) {
    console.error('Error using Gemini API:', error);
    throw error;
  }
}

function normalizeText(text) {
  return text.toLowerCase().replace(/\s+/g, ' ').trim();
}

async function saveVerificationResult(userId, projectId, levelName, result, data) {
  // Save the verification result to Firestore
  await admin.firestore()
    .collection('user_answers')
    .doc(userId)
    .collection('projects')
    .doc(projectId)
    .collection('levels')
    .doc(levelName)
    .set({
      code: data.submittedCode || null,
      output: data.submittedOutput || null,
      text: data.submittedText || null,
      fileUrl: data.fileUrl || null,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      quizScore: data.quizScore || 0,
      attemptCount: data.attemptCount || 1,
      isCorrect: result.isCorrect,
      totalScore: result.totalScore || 0,
      verificationResult: result,
    }, { merge: true });
}