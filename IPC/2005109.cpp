#include <bits/stdc++.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <semaphore.h>
#include <random>
using namespace std;

#define Maximum_corridor_capacity 3
#define Maximum_gallery_capacity 5
#define NUM_STEPS 3

sem_t Gallery1_capacity;
sem_t Corridor_capacity;

pthread_mutex_t stairs1_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t stairs2_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t stairs3_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t hallway_a_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t waiting_area_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t photo_booth_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t reader_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t writer_lock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t print_action = PTHREAD_MUTEX_INITIALIZER;

int reader_count = 0;
int writer_count = 0;

std::random_device rd;
std::mt19937 gen(rd());
std::poisson_distribution<> poisson_dist(3);
std::uniform_int_distribution<> id_dist_standard(1001, 1100);
std::uniform_int_distribution<> id_dist_premium(2001, 2100);

typedef struct
{
    int id;
    int type;
    int hallway_time;
    int step_time;
    int gallery_time;
    int gallery2_time;
    int photo_booth_time;
} Visitor;

timespec start_time;

void time_start()
{
    clock_gettime(CLOCK_MONOTONIC, &start_time);
}

int event_time()
{
    timespec current_time;
    clock_gettime(CLOCK_MONOTONIC, &current_time);
    return current_time.tv_sec - start_time.tv_sec;
}

void Task1(Visitor *visitor)
{
    pthread_mutex_lock(&print_action);
    printf("Visitor %d has arrived at A at  timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    sleep(visitor->hallway_time);

    pthread_mutex_lock(&print_action);
    printf("Visitor %d has arrived at B at  timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    pthread_mutex_lock(&stairs1_lock);

    sleep(visitor->step_time);
    pthread_mutex_lock(&print_action);
    printf("Visitor %d is at step 1 at timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    pthread_mutex_lock(&stairs2_lock);
    pthread_mutex_unlock(&stairs1_lock);

    sleep(visitor->step_time);
    pthread_mutex_lock(&print_action);
    printf("Visitor %d is at step 2 at timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    sleep(rand() % 3);

    pthread_mutex_lock(&stairs3_lock);
    pthread_mutex_unlock(&stairs2_lock);
    sleep(visitor->step_time);

    pthread_mutex_lock(&print_action);
    printf("Visitor %d is at step 3 at timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    sleep(visitor->step_time);

    pthread_mutex_unlock(&stairs3_lock);
}

void Task2(Visitor *visitor)
{
    sem_wait(&Gallery1_capacity);

    pthread_mutex_lock(&print_action);
    printf("Visitor %d is at C(entered Gallery 1) at timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    sleep(visitor->gallery_time);

    pthread_mutex_lock(&print_action);
    printf("Visitor %d is at D(exiting Gallery 1) at timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    sem_post(&Gallery1_capacity);

    sem_wait(&Corridor_capacity);
    sleep(rand() % 3 + 1);
    sem_post(&Corridor_capacity);

    pthread_mutex_lock(&print_action);
    printf("visitor %d is at E (entered Gallery 2) at time %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    sleep(visitor->gallery2_time);
}

void photo_booth_standard(Visitor *visitor)
{

    pthread_mutex_lock(&waiting_area_lock);
    pthread_mutex_lock(&reader_lock);
    reader_count++;
    if (reader_count == 1)
    {
        pthread_mutex_lock(&photo_booth_lock);
    }
    pthread_mutex_unlock(&reader_lock);
    pthread_mutex_unlock(&waiting_area_lock);

    pthread_mutex_lock(&print_action);
    printf("Visitor %d is about to enter the photo booth at timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    sleep(visitor->photo_booth_time);

    pthread_mutex_lock(&print_action);
    printf("Visitor %d inside the photo booth at timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    pthread_mutex_lock(&reader_lock);
    reader_count--;
    if (reader_count == 0)
    {
        pthread_mutex_unlock(&photo_booth_lock);
    }
    pthread_mutex_unlock(&reader_lock);
}

void photo_booth_premium(Visitor *visitor)
{

    pthread_mutex_lock(&writer_lock);
    writer_count++;
    if (writer_count == 1)
    {
        pthread_mutex_lock(&waiting_area_lock);
    }
    pthread_mutex_unlock(&writer_lock);

    pthread_mutex_lock(&photo_booth_lock);

    pthread_mutex_lock(&print_action);
    printf("Visitor %d is about to enter the photo booth at timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    sleep(visitor->photo_booth_time);

    pthread_mutex_lock(&print_action);
    printf("Visitor %d is inside the photo booth at timestamp %d\n", visitor->id, event_time());
    pthread_mutex_unlock(&print_action);

    pthread_mutex_unlock(&photo_booth_lock);

    pthread_mutex_lock(&writer_lock);
    writer_count--;
    if (writer_count == 0)
    {
        pthread_mutex_unlock(&waiting_area_lock);
    }
    pthread_mutex_unlock(&writer_lock);
}

void *Museum_Visit(void *arg)
{
    Visitor *visitor = (Visitor *)arg;
    int timestamp = 1;

    timestamp += poisson_dist(gen);

    usleep(rand() % 10000);

    Task1(visitor);

    Task2(visitor);

    if (visitor->type == 0)
    {
        photo_booth_standard(visitor);
    }
    else
    {
        photo_booth_premium(visitor);
    }

    return NULL;
}

int main()
{

    sem_init(&Gallery1_capacity, 0, Maximum_gallery_capacity);
    sem_init(&Corridor_capacity, 0, Maximum_corridor_capacity);
    int N;
    scanf("%d", &N);
    int M;
    scanf("%d", &M);
    int w, x, y, z;
    scanf("%d", &w);
    scanf("%d", &x);
    scanf("%d", &y);
    scanf("%d", &z);

    time_start();

    pthread_t threads[N + M];
    Visitor visitors[N + M];

    for (int i = 0; i < N; i++)
    {

        visitors[i].id = id_dist_standard(gen);
        visitors[i].type = 0;
        visitors[i].step_time = gen() % 3 + 1;
        visitors[i].gallery_time = x;
        visitors[i].hallway_time = w;
        visitors[i].gallery2_time = y;
        visitors[i].photo_booth_time = z;
        sleep(rand() % 3);
        pthread_create(&threads[i], NULL, Museum_Visit, (void *)&visitors[i]);
    }

    for (int i = N; i < N + M; i++)
    {
        visitors[i].id = id_dist_premium(gen);
        visitors[i].type = 1;
        visitors[i].step_time = gen() % 3 + 1;
        visitors[i].gallery_time = x;
        visitors[i].hallway_time = w;
        visitors[i].gallery2_time = y;
        visitors[i].photo_booth_time = z;
        sleep(rand() % 3);
        pthread_create(&threads[i], NULL, Museum_Visit, (void *)&visitors[i]);
    }

    for (int i = 0; i < N + M; i++)
    {
        pthread_join(threads[i], NULL);
    }

    sem_destroy(&Gallery1_capacity);
    sem_destroy(&Corridor_capacity);
    pthread_mutex_destroy(&stairs1_lock);
    pthread_mutex_destroy(&stairs2_lock);
    pthread_mutex_destroy(&stairs3_lock);
    pthread_mutex_destroy(&hallway_a_lock);
    pthread_mutex_destroy(&waiting_area_lock);
    pthread_mutex_destroy(&photo_booth_lock);
    pthread_mutex_destroy(&reader_lock);
    pthread_mutex_destroy(&writer_lock);
    pthread_mutex_destroy(&print_action);

    return 0;
}
