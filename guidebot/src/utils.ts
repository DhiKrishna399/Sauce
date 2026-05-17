export function isValidBase64(str: string): boolean {
  try {
    return Buffer.from(str, "base64").toString("base64") === str;
  } catch (err) {
    return false;
  }
}

export function truncateBase64ForLogging(base64: string, length: number = 50): string {
  if (base64.length <= length) return base64;
  return base64.substring(0, length) + "...";
}

export function extractJsonFromText(text: string): any {
  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
  } catch (err) {
    console.error("Failed to extract JSON:", err);
  }
  return null;
}
