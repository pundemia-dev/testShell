// Shared language table for the translator page and the AI settings page.
// "auto" is only valid as a source language (the target must be concrete).
.pragma library

var list = [
    { code: "auto", name: "Auto" },
    { code: "en", name: "English" },
    { code: "ru", name: "Russian" },
    { code: "es", name: "Spanish" },
    { code: "fr", name: "French" },
    { code: "de", name: "German" },
    { code: "it", name: "Italian" },
    { code: "pt", name: "Portuguese" },
    { code: "nl", name: "Dutch" },
    { code: "pl", name: "Polish" },
    { code: "uk", name: "Ukrainian" },
    { code: "tr", name: "Turkish" },
    { code: "ar", name: "Arabic" },
    { code: "he", name: "Hebrew" },
    { code: "hi", name: "Hindi" },
    { code: "ja", name: "Japanese" },
    { code: "ko", name: "Korean" },
    { code: "zh", name: "Chinese" },
    { code: "vi", name: "Vietnamese" },
    { code: "th", name: "Thai" },
    { code: "id", name: "Indonesian" },
    { code: "cs", name: "Czech" },
    { code: "sv", name: "Swedish" },
    { code: "fi", name: "Finnish" },
    { code: "el", name: "Greek" },
    { code: "ro", name: "Romanian" },
    { code: "hu", name: "Hungarian" },
    { code: "da", name: "Danish" },
    { code: "nb", name: "Norwegian" }
];

function name(code) {
    for (var i = 0; i < list.length; i++)
        if (list[i].code === code)
            return list[i].name;
    return code;
}
