import cv2
import mediapipe as mp

imageWidth = 1280
imageHeight = 720

def handArea(pos, deadzone = 1/3):
    area = ""
    xDeadzoneLeft = int((imageWidth - imageWidth*deadzone)/2) 
    xDeadzoneRight = int((imageWidth + imageWidth*deadzone)/2)
    yDeadzoneUp = int((imageHeight - imageHeight*deadzone)/2)
    yDeadzoneDown = int((imageHeight + imageHeight*deadzone)/2)
    if pos[1] < yDeadzoneUp:
        area = area + "Upper "
    elif yDeadzoneUp < pos[1] < yDeadzoneDown:
        area = area + "Middle "
    else:
        area = area + "Lower "
    
    if pos[0] < xDeadzoneLeft:
        area = area + "Left "
    elif xDeadzoneLeft < pos[0] < xDeadzoneRight:
        area = area + "Center "
    else:
        area = area + "Right "
    
    print(area)

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, value=imageWidth)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, value=imageHeight)

mp_drawing = mp.solutions.drawing_utils
mp_hands = mp.solutions.hands
hand = mp_hands.Hands()


i = 0
while True:
    success, frame = cap.read()
    if success:
        RGB_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        result = hand.process(RGB_frame)
        if result.multi_hand_landmarks:
            for hand_landmarks in result.multi_hand_landmarks:
                if i == 10:
                    wrist_landmark = hand_landmarks.landmark[mp_hands.HandLandmark.WRIST]
                    wrist_position = [imageWidth - int(wrist_landmark.x*imageWidth), int(wrist_landmark.y*imageHeight)]
                    handArea(wrist_position)
                    i = -1
                i += 1
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
        frame = cv2.flip(frame,1)
        cv2.imshow("capture image", frame)
        if cv2.waitKey(1) == ord('q'):
            break

cv2.destroyAllWindows()

