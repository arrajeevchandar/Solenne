import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import test, { after, before, beforeEach } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  endAt,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  startAt,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'solenne-rules-test';
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(import.meta.dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment?.cleanup());

function database(uid) {
  return environment.authenticatedContext(uid).firestore();
}

async function seed(callback) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await callback(context.firestore());
  });
}

async function register(uid, username) {
  const db = database(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, 'users', uid), {
    displayName: uid,
    username,
    usernameNormalized: username,
  });
  batch.set(doc(db, 'usernames', username), {
    uid,
    username,
    usernameNormalized: username,
    displayName: uid,
    photoUrl: '',
    updatedAt: serverTimestamp(),
  });
  return batch.commit();
}

function profile(uid, username) {
  return { uid, displayName: uid, username, photoUrl: '' };
}

async function seedAcceptedFriendshipAndJournal() {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', 'owner', 'journals', 'journal-1'), {
      id: 'journal-1',
      userId: 'owner',
      entryType: 'written',
      title: '',
      prompt: 'Daily reflection',
      recordedAt: new Date('2026-08-12T12:00:00Z'),
      durationSeconds: 0,
      videoUrl: '',
      audioUrl: '',
      writtenText: 'A private reflection selected for sharing.',
      mediaMimeType: 'text/plain',
      thumbnailUrl: '',
      uploadStatus: 'saved',
      analysisStatus: 'complete',
      analysisStep: 'complete',
      analysisVersion: '2026-08-v9-gpt-oss-insights',
      moodLabel: null,
      aiInsights: [],
      insightProvider: 'groq',
      transcript: {},
    });
    await setDoc(doc(db, 'friendships', 'friend_owner'), {
      requesterId: 'owner',
      recipientId: 'friend',
      memberIds: ['friend', 'owner'],
      status: 'accepted',
      profiles: {
        owner: profile('owner', 'owner_name'),
        friend: profile('friend', 'friend_name'),
      },
    });
  });
}

function validShare(includeTranscript = false) {
  return {
    ownerId: 'owner',
    recipientId: 'friend',
    journalId: 'journal-1',
    friendshipId: 'friend_owner',
    memberIds: ['friend', 'owner'],
    status: 'active',
    includeTranscript,
    ownerProfile: profile('owner', 'owner_name'),
    recipientProfile: profile('friend', 'friend_name'),
    journal: {
      id: 'journal-1',
      userId: 'owner',
      entryType: 'written',
      title: '',
      prompt: 'Daily reflection',
      recordedAt: new Date('2026-08-12T12:00:00Z'),
      durationSeconds: 0,
      videoUrl: '',
      audioUrl: '',
      writtenText: 'A private reflection selected for sharing.',
      mediaMimeType: 'text/plain',
      thumbnailUrl: '',
      uploadStatus: 'saved',
      analysisStatus: 'complete',
      analysisStep: 'complete',
      analysisVersion: '2026-08-v9-gpt-oss-insights',
      moodLabel: null,
      aiInsights: [],
      insightProvider: 'groq',
    },
    analysisVersion: '2026-08-v9-gpt-oss-insights',
    sharedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

test('username reservation and profile write are atomic and unique', async () => {
  await assertSucceeds(register('owner', 'quiet_moon'));
  await assertFails(register('other', 'quiet_moon'));
});

test('legacy profile can atomically reserve its generated username', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', 'legacy-user'), {
      displayName: 'Legacy Friend',
      email: 'legacy@example.com',
      onboardingComplete: true,
    });
  });

  const db = database('legacy-user');
  const batch = writeBatch(db);
  batch.set(
    doc(db, 'users', 'legacy-user'),
    {
      username: 'legacy_friend',
      usernameNormalized: 'legacy_friend',
      consentSource: 'legacy_assumed',
      aiConsentGranted: true,
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  );
  batch.set(doc(db, 'usernames', 'legacy_friend'), {
    uid: 'legacy-user',
    username: 'legacy_friend',
    usernameNormalized: 'legacy_friend',
    displayName: 'Legacy Friend',
    photoUrl: '',
    updatedAt: serverTimestamp(),
  });

  await assertSucceeds(batch.commit());
});

test('mixed-case legacy reservation can be atomically canonicalized', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', 'legacy-user'), {
      displayName: 'Legacy Friend',
      username: 'legacy_AbC123',
      usernameNormalized: 'legacy_AbC123',
    });
    await setDoc(doc(db, 'usernames', 'legacy_AbC123'), {
      uid: 'legacy-user',
      username: 'legacy_AbC123',
      usernameNormalized: 'legacy_AbC123',
      displayName: 'Legacy Friend',
      photoUrl: '',
      updatedAt: serverTimestamp(),
    });
  });

  const db = database('legacy-user');
  await assertSucceeds(
    runTransaction(db, async (transaction) => {
      const userRef = doc(db, 'users', 'legacy-user');
      const oldRef = doc(db, 'usernames', 'legacy_AbC123');
      const newRef = doc(db, 'usernames', 'legacy_abc123');
      await transaction.get(userRef);
      await transaction.get(oldRef);
      await transaction.get(newRef);
      transaction.set(newRef, {
        uid: 'legacy-user',
        username: 'legacy_abc123',
        usernameNormalized: 'legacy_abc123',
        displayName: 'Legacy Friend',
        photoUrl: '',
        updatedAt: serverTimestamp(),
      });
      transaction.update(userRef, {
        username: 'legacy_abc123',
        usernameNormalized: 'legacy_abc123',
        updatedAt: serverTimestamp(),
      });
      transaction.delete(oldRef);
    }),
  );
});

test('canonical username prefix and exact search return another user', async () => {
  await assertSucceeds(register('owner', 'owner_name'));
  await assertSucceeds(register('friend', 'shambhavi_atsvq9'));
  const db = database('owner');
  const results = await assertSucceeds(
    getDocs(
      query(
        collection(db, 'usernames'),
        orderBy('usernameNormalized'),
        startAt('shambhavi_atsvq9'),
        endAt('shambhavi_atsvq9\uf8ff'),
      ),
    ),
  );
  const usernames = results.docs.map((item) => item.data().username);
  if (!usernames.includes('shambhavi_atsvq9')) {
    throw new Error('Canonical exact username was not returned by search.');
  }
});

test('owner can atomically retry only their failed analysis', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', 'owner'), {
      username: 'owner_name',
      usernameNormalized: 'owner_name',
    });
    await setDoc(doc(db, 'users', 'owner', 'journals', 'retry-journal'), {
      id: 'retry-journal',
      userId: 'owner',
      analysisStatus: 'failed',
      analysisStep: 'failed',
      analysisVersion: 'old-version',
      analysisError: 'Insights unavailable.',
      analysisErrorCode: 'ai_insights_unavailable',
      aiInsights: [{ title: 'Bad fallback' }],
      templateInsights: [],
      insightProvider: 'fallback',
    });
    await setDoc(doc(db, 'analysis_jobs', 'retry-journal'), {
      userId: 'owner',
      journalId: 'retry-journal',
      status: 'failed',
      processingStep: 'failed',
      analysisVersion: 'old-version',
      attemptCount: 1,
      retryCount: 1,
      startedAt: null,
      completedAt: new Date(),
      errorMessage: 'Insights unavailable.',
    });
  });

  const db = database('owner');
  const batch = writeBatch(db);
  batch.update(doc(db, 'analysis_jobs', 'retry-journal'), {
    status: 'queued',
    processingStep: 'queued',
    analysisVersion: '2026-08-v9-gpt-oss-insights',
    startedAt: null,
    completedAt: null,
    errorMessage: null,
    attemptCount: 0,
    retryCount: 0,
    requestedAt: serverTimestamp(),
  });
  batch.update(doc(db, 'users', 'owner', 'journals', 'retry-journal'), {
    analysisStatus: 'queued',
    analysisStep: 'queued',
    analysisVersion: '2026-08-v9-gpt-oss-insights',
    analysisError: null,
    analysisErrorCode: null,
    analysisRequestedAt: serverTimestamp(),
    aiInsights: [],
    templateInsights: [],
    insightProvider: '',
  });
  await assertSucceeds(batch.commit());
});

test('withdrawn AI consent saves a journal but cannot create analysis work', async () => {
  await assertSucceeds(register('owner', 'owner_name'));
  const db = database('owner');
  await assertSucceeds(
    updateDoc(doc(db, 'users', 'owner'), { aiConsentGranted: false }),
  );

  await assertSucceeds(
    setDoc(doc(db, 'users', 'owner', 'journals', 'private-journal'), {
      id: 'private-journal',
      userId: 'owner',
      analysisStatus: 'not_requested',
      analysisStep: 'consent_withdrawn',
    }),
  );

  await assertFails(
    setDoc(doc(db, 'analysis_jobs', 'private-journal'), {
      userId: 'owner',
      journalId: 'private-journal',
      status: 'queued',
      processingStep: 'queued',
      retryCount: 0,
      attemptCount: 0,
    }),
  );
});

test('friendships reject outsiders and forged membership', async () => {
  await assertSucceeds(register('owner', 'owner_name'));
  const ownerDb = database('owner');
  await assertFails(
    setDoc(doc(ownerDb, 'friendships', 'forged'), {
      requesterId: 'owner',
      recipientId: 'friend',
      memberIds: ['owner', 'outsider'],
      status: 'pending',
      profiles: {
        owner: profile('owner', 'owner_name'),
        outsider: profile('outsider', 'outsider_name'),
      },
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  await seedAcceptedFriendshipAndJournal();
  await assertFails(
    getDoc(doc(database('outsider'), 'friendships', 'friend_owner')),
  );
});

test('a registered user can send a valid friendship request', async () => {
  await assertSucceeds(register('owner', 'owner_name'));
  await assertSucceeds(register('friend', 'friend_name'));
  const ownerDb = database('owner');
  const friendshipRef = doc(ownerDb, 'friendships', 'friend_owner');

  await assertSucceeds(
    runTransaction(ownerDb, async (transaction) => {
      const existing = await transaction.get(friendshipRef);
      if (existing.exists()) return;
      transaction.set(friendshipRef, {
        requesterId: 'owner',
        recipientId: 'friend',
        memberIds: ['friend', 'owner'],
        status: 'pending',
        profiles: {
          owner: profile('owner', 'owner_name'),
          friend: profile('friend', 'friend_name'),
        },
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }),
  );

  await assertSucceeds(
    getDoc(doc(database('friend'), 'friendships', friendshipRef.id)),
  );
});

test('an accepted member can query active shares and remove a friendship', async () => {
  await seedAcceptedFriendshipAndJournal();
  const ownerDb = database('owner');
  const activeShares = query(
    collection(ownerDb, 'journal_shares'),
    where('memberIds', 'array-contains', 'owner'),
    where('friendshipId', '==', 'friend_owner'),
    where('status', '==', 'active'),
  );
  const shares = await assertSucceeds(getDocs(activeShares));
  const batch = writeBatch(ownerDb);
  batch.update(doc(ownerDb, 'friendships', 'friend_owner'), {
    status: 'removed',
    removedBy: 'owner',
    updatedAt: serverTimestamp(),
  });
  for (const share of shares.docs) batch.delete(share.ref);
  await assertSucceeds(batch.commit());
});

test('friends cannot read the owner private journal', async () => {
  await seedAcceptedFriendshipAndJournal();
  await assertFails(
    getDoc(doc(database('friend'), 'users', 'owner', 'journals', 'journal-1')),
  );
});

function conversationData(messageId = 'message-1', preview = 'Hello') {
  return {
    memberIds: ['friend', 'owner'],
    profiles: {
      owner: profile('owner', 'owner_name'),
      friend: profile('friend', 'friend_name'),
    },
    active: true,
    schemaVersion: 1,
    lastMessageId: messageId,
    lastMessagePreview: preview,
    lastMessageAt: serverTimestamp(),
    lastMessageSenderId: 'owner',
    unreadCounts: { owner: 0, friend: 1 },
    deliveredThrough: { owner: serverTimestamp() },
    readThrough: { owner: serverTimestamp() },
    typing: {
      owner: { active: false, updatedAt: serverTimestamp() },
    },
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

function messageData(senderId = 'owner', body = 'Hello') {
  return {
    senderId,
    type: 'text',
    body,
    shareId: '',
    createdAt: serverTimestamp(),
    deleted: false,
    deletedAt: null,
  };
}

test('accepted friends can open and transactionally create a first conversation', async () => {
  await seedAcceptedFriendshipAndJournal();
  const ownerDb = database('owner');
  const conversation = doc(ownerDb, 'conversations', 'friend_owner');
  const messages = collection(ownerDb, 'conversations', 'friend_owner', 'messages');

  const missingConversation = await assertSucceeds(getDoc(conversation));
  assert.equal(missingConversation.exists(), false);
  const emptyMessages = await assertSucceeds(getDocs(messages));
  assert.equal(emptyMessages.empty, true);
  await assertFails(getDoc(doc(database('outsider'), 'conversations', 'friend_owner')));

  const first = doc(messages, 'message-1');
  await assertSucceeds(
    runTransaction(ownerDb, async (transaction) => {
      const current = await transaction.get(conversation);
      assert.equal(current.exists(), false);
      transaction.set(conversation, conversationData());
      transaction.set(first, messageData());
    }),
  );

  const created = await assertSucceeds(getDoc(conversation));
  assert.equal(created.data().unreadCounts.friend, 1);
  const createdMessages = await assertSucceeds(getDocs(messages));
  assert.equal(createdMessages.size, 1);
});

test('removed friends cannot open an uncreated conversation or message list', async () => {
  await seedAcceptedFriendshipAndJournal();
  await seed(async (db) => {
    await updateDoc(doc(db, 'friendships', 'friend_owner'), {
      status: 'removed',
    });
  });

  const ownerDb = database('owner');
  await assertFails(getDoc(doc(ownerDb, 'conversations', 'friend_owner')));
  await assertFails(
    getDocs(collection(ownerDb, 'conversations', 'friend_owner', 'messages')),
  );
});

test('accepted friends create and continue one conversation atomically', async () => {
  await seedAcceptedFriendshipAndJournal();
  const ownerDb = database('owner');
  const conversation = doc(ownerDb, 'conversations', 'friend_owner');
  const first = doc(ownerDb, 'conversations', 'friend_owner', 'messages', 'message-1');
  const createBatch = writeBatch(ownerDb);
  createBatch.set(conversation, conversationData());
  createBatch.set(first, messageData());
  await assertSucceeds(createBatch.commit());

  const second = doc(ownerDb, 'conversations', 'friend_owner', 'messages', 'message-2');
  const continueBatch = writeBatch(ownerDb);
  continueBatch.update(conversation, {
    lastMessageId: 'message-2',
    lastMessagePreview: 'Still here',
    lastMessageAt: serverTimestamp(),
    lastMessageSenderId: 'owner',
    'unreadCounts.owner': 0,
    'unreadCounts.friend': 2,
    'deliveredThrough.owner': serverTimestamp(),
    'readThrough.owner': serverTimestamp(),
    'typing.owner': { active: false, updatedAt: serverTimestamp() },
    updatedAt: serverTimestamp(),
  });
  continueBatch.set(second, messageData('owner', 'Still here'));
  await assertSucceeds(continueBatch.commit());
});

test('message sender identity and receipt ownership cannot be forged', async () => {
  await seedAcceptedFriendshipAndJournal();
  const ownerDb = database('owner');
  const conversation = doc(ownerDb, 'conversations', 'friend_owner');
  const first = doc(ownerDb, 'conversations', 'friend_owner', 'messages', 'message-1');
  const batch = writeBatch(ownerDb);
  batch.set(conversation, conversationData());
  batch.set(first, messageData());
  await batch.commit();

  await assertFails(
    setDoc(
      doc(ownerDb, 'conversations', 'friend_owner', 'messages', 'forged'),
      messageData('friend', 'Forged'),
    ),
  );
  await assertFails(
    updateDoc(doc(database('friend'), 'conversations', 'friend_owner'), {
      'unreadCounts.owner': 0,
      'deliveredThrough.owner': serverTimestamp(),
      'readThrough.owner': serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(doc(database('friend'), 'conversations', 'friend_owner'), {
      'unreadCounts.friend': 0,
      'deliveredThrough.friend': serverTimestamp(),
      'readThrough.friend': serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('removing a friend deactivates chat and blocks later messages', async () => {
  await seedAcceptedFriendshipAndJournal();
  const ownerDb = database('owner');
  const conversation = doc(ownerDb, 'conversations', 'friend_owner');
  const first = doc(ownerDb, 'conversations', 'friend_owner', 'messages', 'message-1');
  const createBatch = writeBatch(ownerDb);
  createBatch.set(conversation, conversationData());
  createBatch.set(first, messageData());
  await createBatch.commit();

  const removeBatch = writeBatch(ownerDb);
  removeBatch.update(doc(ownerDb, 'friendships', 'friend_owner'), {
    status: 'removed',
    removedBy: 'owner',
    updatedAt: serverTimestamp(),
  });
  removeBatch.update(conversation, {
    active: false,
    typing: {},
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(removeBatch.commit());
  await assertFails(getDoc(conversation));
  await assertFails(
    setDoc(
      doc(ownerDb, 'conversations', 'friend_owner', 'messages', 'late'),
      messageData('owner', 'Too late'),
    ),
  );
});

test('shares reject raw metrics and transcript without opt-in', async () => {
  await seedAcceptedFriendshipAndJournal();
  const ownerDb = database('owner');
  const unsafeMetrics = validShare();
  unsafeMetrics.journal.facial = { confidence: 0.9 };
  await assertFails(
    setDoc(doc(ownerDb, 'journal_shares', 'unsafe-metrics'), unsafeMetrics),
  );

  const unsafeTranscript = validShare();
  unsafeTranscript.journal.transcript = { text: 'Not opted in.' };
  await assertFails(
    setDoc(doc(ownerDb, 'journal_shares', 'unsafe-transcript'), unsafeTranscript),
  );
});

test('sanitized shares are recipient-readable, revocable, and blocked after unfriend', async () => {
  await seedAcceptedFriendshipAndJournal();
  const ownerDb = database('owner');
  const shareRef = doc(ownerDb, 'journal_shares', 'owner_journal-1_friend');
  await assertSucceeds(setDoc(shareRef, validShare()));
  await assertSucceeds(
    getDoc(doc(database('friend'), 'journal_shares', shareRef.id)),
  );
  const friendInbox = query(
    collection(database('friend'), 'journal_shares'),
    where('recipientId', '==', 'friend'),
    where('status', '==', 'active'),
    orderBy('sharedAt', 'desc'),
  );
  const ownerOutbox = query(
    collection(ownerDb, 'journal_shares'),
    where('ownerId', '==', 'owner'),
    where('status', '==', 'active'),
    orderBy('sharedAt', 'desc'),
  );
  const inbox = await assertSucceeds(getDocs(friendInbox));
  const outbox = await assertSucceeds(getDocs(ownerOutbox));
  assert.equal(inbox.size, 1);
  assert.equal(outbox.size, 1);

  await seed(async (db) => {
    await updateDoc(doc(db, 'friendships', 'friend_owner'), {
      status: 'removed',
    });
  });
  await assertFails(
    getDoc(doc(database('friend'), 'journal_shares', shareRef.id)),
  );
  await assertSucceeds(
    deleteDoc(doc(database('owner'), 'journal_shares', shareRef.id)),
  );
});
