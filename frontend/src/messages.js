export function messageKey(msg) {
  return msg.id || `${msg.timestamp}-${msg.senderId}-${msg.content}`;
}

export function isPrivateBetween(msg, userId, peerId) {
  return msg.type?.toString() === 'PRIVATE' && (
    (msg.senderId === userId && msg.recipientId === peerId) ||
    (msg.senderId === peerId && msg.recipientId === userId)
  );
}

export function isGroupMessage(msg, groupId) {
  return msg.type?.toString() === 'GROUP' && msg.recipientId === groupId;
}

export function mergeMessages(existing, incoming) {
  const merged = new Map();
  [...existing, ...incoming].forEach((msg) => {
    merged.set(messageKey(msg), msg);
  });
  return [...merged.values()].sort(
    (a, b) => new Date(a.timestamp || 0) - new Date(b.timestamp || 0),
  );
}
